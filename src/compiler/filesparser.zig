const std = @import("std");
const ast = @import("../ast/pkg.zig");
const collections = @import("../collections/pkg.zig");
const core = @import("../core/pkg.zig");
const diagnostics = @import("../diagnostics/pkg.zig");
const module = @import("../module/pkg.zig");
const tracing = @import("../tracing/pkg.zig");
const tsoptions = @import("../tsoptions/pkg.zig");
const tspath = @import("../tspath/pkg.zig");

const fileInclude = @import("fileInclude.zig");
const processingDiagnostic = @import("processingDiagnostic.zig");

pub const LibFile = struct {
    name: []const u8,
    path: []const u8,
    replaced: bool,
};

pub const ParseTask = struct {
    normalizedFilePath: []const u8,
    path: tspath.Path,
    file: ast.SourceFileIndex,
    libFile: ?*LibFile,
    redirectedParseTask: ?*ParseTask,
    subTasks: std.ArrayList(*ParseTask),
    loaded: bool,
    startedSubTasks: bool,
    isForAutomaticTypeDirective: bool,
    includeReason: ?*fileInclude.FileIncludeReason,
    packageId: module.PackageId,

    metadata: ast.SourceFileMetaData,
    resolutionsInFile: module.ModeAwareCache(*module.ResolvedModule),
    resolutionsTrace: std.ArrayList(module.DiagAndArgs),
    typeResolutionsInFile: module.ModeAwareCache(*module.ResolvedTypeReferenceDirective),
    typeResolutionsTrace: std.ArrayList(module.DiagAndArgs),
    resolutionDiagnostics: std.ArrayList(ast.DiagnosticIndex),
    processingDiagnostics: std.ArrayList(*processingDiagnostic.ProcessingDiagnostic),
    importHelpersImportSpecifier: ast.NodeIndex, // StringLiteralNode
    jsxRuntimeImportSpecifier: ?*anyopaque, // jsxRuntimeImportSpecifier

    increaseDepth: bool,
    elideOnDepth: bool,

    loadedTask: ?*ParseTask,
    allIncludeReasons: std.ArrayList(*fileInclude.FileIncludeReason),
};

pub const ResolvedRef = struct {
    fileName: []const u8,
    increaseDepth: bool,
    elideOnDepth: bool,
    includeReason: ?*fileInclude.FileIncludeReason,
    packageId: module.PackageId,
};

pub const FilesParser = struct {
    wg: core.WorkGroup,
    taskDataByPath: collections.SyncMap(tspath.Path, *ParseTaskData),
    maxDepth: usize,
};

pub const ParseTaskData = struct {
    tasks: std.StringHashMap(*ParseTask),
    mu: std.Thread.Mutex,
    lowestDepth: usize,
    startedSubTasks: bool,
    packageId: module.PackageId,
};

pub const FileLoader = struct {
    // Skeleton implementation
};
