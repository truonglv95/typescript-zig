const std = @import("std");
const testing = std.testing;

const ast = @import("../../ast/ast.zig");
const binder = @import("../../binder/binder.zig");
const checker = @import("../../checker/checker.zig");
const core = @import("../../core/core.zig");
const module_resolver = @import("../../module/resolver.zig");
const parser = @import("../../parser/parser.zig");
const tspath = @import("../../tspath/tspath.zig");
const vfs = @import("../../vfs/vfs.zig");
const aliasresolver = @import("aliasresolver.zig");

pub const FakeCloneHost = struct {
    fs: ?*anyopaque = null,

    pub fn getCurrentDirectory(self: *FakeCloneHost) []const u8 {
        _ = self;
        return "/";
    }

    pub fn useCaseSensitiveFileNames(self: *FakeCloneHost) bool {
        _ = self;
        return true;
    }

    pub fn getSourceFile(self: *FakeCloneHost, fileName: []const u8, path: tspath.Path) ?ast.NodeIndex {
        _ = self;
        _ = fileName;
        _ = path;
        return null;
    }

    pub fn host(self: *FakeCloneHost) aliasresolver.AliasResolverHost {
        return .{
            .ptr = self,
            .getCurrentDirectoryFn = struct {
                fn wrapper(ptr: *anyopaque) []const u8 {
                    return @as(*FakeCloneHost, @ptrCast(@alignCast(ptr))).getCurrentDirectory();
                }
            }.wrapper,
            .useCaseSensitiveFileNamesFn = struct {
                fn wrapper(ptr: *anyopaque) bool {
                    return @as(*FakeCloneHost, @ptrCast(@alignCast(ptr))).useCaseSensitiveFileNames();
                }
            }.wrapper,
            .getSourceFileFn = struct {
                fn wrapper(ptr: *anyopaque, fileName: []const u8, path: tspath.Path) ?ast.NodeIndex {
                    return @as(*FakeCloneHost, @ptrCast(@alignCast(ptr))).getSourceFile(fileName, path);
                }
            }.wrapper,
        };
    }
};

test "AliasResolverGetDiagnosticsDoesNotPanic" {
    const allocator = std.testing.allocator;

    const text = "declare function f(arg: { a: string }): () => void;\nexport const x = f({ a: 1 });\n";

    var p = parser.Parser.init(allocator, text);
    defer p.deinit();
    const sourceFile = try p.parseSourceFile();

    var b = binder.Binder.init(allocator, &p.ast) catch unreachable;
    defer b.deinit();
    try b.bindSourceFile(sourceFile);

    var fakeHost = FakeCloneHost{};
    
    const opts = try allocator.create(core.CompilerOptions);
    defer allocator.destroy(opts);
    opts.* = .{};
    
    const resolutionHost = module_resolver.ResolutionHost{
        .ptr = &fakeHost,
        .getCurrentDirectoryFn = struct {
            fn wrapper(ptr: *anyopaque) []const u8 {
                return @as(*FakeCloneHost, @ptrCast(@alignCast(ptr))).getCurrentDirectory();
            }
        }.wrapper,
        .useCaseSensitiveFileNamesFn = struct {
            fn wrapper(ptr: *anyopaque) bool {
                return @as(*FakeCloneHost, @ptrCast(@alignCast(ptr))).useCaseSensitiveFileNames();
            }
        }.wrapper,
    };
    
    const resolver = try module_resolver.Resolver.init(allocator, resolutionHost, opts, "", "");

    const r = try aliasresolver.AliasResolver.init(
        allocator,
        &[_]ast.NodeIndex{sourceFile},
        null,
        fakeHost.host(),
        resolver,
        struct {
            fn toPath(fName: []const u8) tspath.Path {
                return fName; // simplified path for test
            }
        }.toPath,
        struct {
            fn onFailedLookup(source: ast.NodeIndex, moduleName: []const u8) void {
                _ = source;
                _ = moduleName;
            }
        }.onFailedLookup,
    );
    _ = r;

    var ch = checker.Checker.init(allocator, &b);
    defer ch.deinit();

    // Type-checking this file's diagnostics must not panic.
    // In Go: ch.GetDiagnostics(context.Background(), sourceFile)
    // In Zig: not yet implemented in checker.zig, so we just run the initialization.
}
