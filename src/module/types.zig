const std = @import("std");
const ast = @import("../ast/ast.zig");
const core = @import("../core/core.zig");
const tspath = @import("../tspath/tspath.zig");

pub const ModeAwareCacheKey = struct {
    name: []const u8,
    mode: core.ResolutionMode,
};

pub const NodeResolutionFeatures = packed struct {
    imports: bool = false,
    selfName: bool = false,
    exports: bool = false,
    exportsPatternTrailers: bool = false,
    importsPatternRoot: bool = false,
    _padding: u27 = 0,

    pub const None = NodeResolutionFeatures{};
    pub const All = NodeResolutionFeatures{
        .imports = true,
        .selfName = true,
        .exports = true,
        .exportsPatternTrailers = true,
        .importsPatternRoot = true,
    };
    pub const Node16Default = NodeResolutionFeatures{
        .imports = true,
        .selfName = true,
        .exports = true,
        .exportsPatternTrailers = true,
    };
    pub const NodeNextDefault = All;
    pub const BundlerDefault = NodeResolutionFeatures{
        .imports = true,
        .selfName = true,
        .exports = true,
        .exportsPatternTrailers = true,
        .importsPatternRoot = true,
    };
};

pub const PackageId = struct {
    name: []const u8 = "",
    subModuleName: []const u8 = "",
    version: []const u8 = "",
    peerDependencies: []const u8 = "",

    pub fn packageName(self: PackageId, allocator: std.mem.Allocator) ![]const u8 {
        if (self.subModuleName.len > 0) {
            return try std.fmt.allocPrint(allocator, "{s}/{s}", .{self.name, self.subModuleName});
        }
        return try allocator.dupe(u8, self.name);
    }
};

pub const ResolvedModule = struct {
    resolutionDiagnostics: std.ArrayList(*ast.Diagnostic),
    resolvedFileName: []const u8 = "",
    originalPath: []const u8 = "",
    extension: []const u8 = "",
    resolvedUsingTsExtension: bool = false,
    packageId: ?PackageId = null,
    isExternalLibraryImport: bool = false,
    alternateResult: []const u8 = "",

    pub fn isResolved(self: *const ResolvedModule) bool {
        return self.resolvedFileName.len > 0;
    }
};

pub const ResolvedTypeReferenceDirective = struct {
    resolutionDiagnostics: std.ArrayList(*ast.Diagnostic),
    primary: bool = false,
    resolvedFileName: []const u8 = "",
    originalPath: []const u8 = "",
    packageId: ?PackageId = null,
    isExternalLibraryImport: bool = false,

    pub fn isResolved(self: *const ResolvedTypeReferenceDirective) bool {
        return self.resolvedFileName.len > 0;
    }
};

pub const Extensions = packed struct {
    typeScript: bool = false,
    javaScript: bool = false,
    declaration: bool = false,
    json: bool = false,
    _padding: u28 = 0,

    pub const TypeScript = Extensions{ .typeScript = true };
    pub const JavaScript = Extensions{ .javaScript = true };
    pub const Declaration = Extensions{ .declaration = true };
    pub const Json = Extensions{ .json = true };
    pub const ImplementationFiles = Extensions{ .typeScript = true, .javaScript = true };
};

pub const ResolvedEntrypoint = struct {
    name: []const u8,
    resolvedFileName: []const u8,
};
