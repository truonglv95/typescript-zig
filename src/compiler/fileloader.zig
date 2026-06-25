const std = @import("std");
const ast = @import("../ast/ast.zig");
const collections = @import("../collections/collections.zig");
const core = @import("../core/core.zig");
const diagnostics = @import("../diagnostics/diagnostics.zig");
const module_pkg = @import("../module/module.zig");
const tracing = @import("../tracing/tracing.zig");
const tsoptions = @import("../tsoptions/tsoptions.zig");
const tspath = @import("../tspath/tspath.zig");
const xxh3 = @import("../zeebo/xxh3/xxh3.zig");

// These types are expected to be in the compiler package
const ProgramOptions = @import("program.zig").ProgramOptions;
const filesParser = @import("files_parser.zig").filesParser;
const parseTask = @import("parse_task.zig").parseTask;
const projectReferenceFileMapper = @import("project_reference.zig").projectReferenceFileMapper;
const FileIncludeReason = @import("file_include_reason.zig").FileIncludeReason;
const processingDiagnostic = @import("processing_diagnostic.zig").processingDiagnostic;

pub const LibResolution = struct {
    libraryName: []const u8,
    resolution: *module_pkg.ResolvedModule,
    trace: []module_pkg.DiagAndArgs,
};

pub const LibFile = struct {
    name: []const u8,
    path: []const u8,
    replaced: bool,
};

pub const SourceFileFromReferenceDiagnostic = struct {
    message: *const diagnostics.Message,
    args: [][]const u8,
};

pub const FileLoader = struct {
    opts: ProgramOptions,
    resolver: *module_pkg.Resolver,
    defaultLibraryPath: []const u8,
    comparePathsOptions: tspath.ComparePathsOptions,
    supportedExtensions: [][]const []const u8,
    supportedExtensionsWithJsonIfResolveJsonModule: [][]const []const u8,

    filesParserInst: *filesParser,
    rootTasks: std.ArrayList(*parseTask),

    totalFileCount: std.atomic.Value(i32),
    libFileCount: std.atomic.Value(i32),

    factoryMu: std.Thread.Mutex,
    // factory: ast.NodeFactory, // Not directly mapped in DoD

    projectReferenceFileMapperInst: *projectReferenceFileMapper,
    dtsDirectories: collections.Set(tspath.Path),

    pathForLibFileCache: collections.SyncMap([]const u8, *LibFile),
    pathForLibFileResolutions: collections.SyncMap(tspath.Path, *LibResolution),
};

pub const RedirectsFile = struct {
    index: usize,
    fileName: []const u8,
    path: tspath.Path,
    target: tspath.Path,

    pub fn getFileName(self: *RedirectsFile) []const u8 {
        return self.fileName;
    }

    pub fn getPath(self: *RedirectsFile) tspath.Path {
        return self.path;
    }
};

pub const DuplicateSourceFile = struct {
    parseOptions: ast.SourceFileParseOptions,
    hash: xxh3.Uint128,
    scriptKind: core.ScriptKind,
};

pub const ProcessedFiles = struct {
    resolver: *module_pkg.Resolver,
    files: []ast.NodeIndex, // Using NodeIndex instead of *ast.SourceFile
    duplicateSourceFiles: []*DuplicateSourceFile,
    filesByPath: std.AutoHashMap(tspath.Path, ast.NodeIndex),
    projectReferenceFileMapperInst: *projectReferenceFileMapper,
    missingFiles: [][]const u8,
    resolvedModules: std.AutoHashMap(tspath.Path, module_pkg.ModeAwareCache(*module_pkg.ResolvedModule)),
    typeResolutionsInFile: std.AutoHashMap(tspath.Path, module_pkg.ModeAwareCache(*module_pkg.ResolvedTypeReferenceDirective)),
    sourceFileMetaDatas: std.AutoHashMap(tspath.Path, ast.SourceFileMetaData),
    jsxRuntimeImportSpecifiers: std.AutoHashMap(tspath.Path, *JsxRuntimeImportSpecifier),
    importHelpersImportSpecifiers: std.AutoHashMap(tspath.Path, ast.NodeIndex), // ast.StringLiteralNode is a NodeIndex
    libFiles: std.AutoHashMap(tspath.Path, *LibFile),
    sourceFilesFoundSearchingNodeModules: collections.Set(tspath.Path),
    // includeProcessor: *includeProcessor, // Not defined yet
    outputFileToProjectReferenceSource: std.AutoHashMap(tspath.Path, []const u8),
    redirectTargetsMap: std.AutoHashMap(tspath.Path, [][]const u8),
    redirectFilesByPath: std.AutoHashMap(tspath.Path, *RedirectsFile),
    finishedProcessing: bool,
};

pub const JsxRuntimeImportSpecifier = struct {
    moduleReference: []const u8,
    specifier: ast.NodeIndex, // ast.StringLiteralNode
};

pub fn processAllProgramFiles(
    allocator: std.mem.Allocator,
    opts: ProgramOptions,
    singleThreaded: bool,
) ProcessedFiles {
    _ = allocator;
    _ = opts;
    _ = singleThreaded;
    @panic("Not implemented");
}

pub fn toPath(loader: *FileLoader, file: []const u8) tspath.Path {
    _ = loader;
    _ = file;
    @panic("Not implemented");
}

pub fn addRootTask(loader: *FileLoader, fileName: []const u8, libFile: ?*LibFile, includeReason: *FileIncludeReason) void {
    _ = loader;
    _ = fileName;
    _ = libFile;
    _ = includeReason;
    @panic("Not implemented");
}

pub fn addRootFileTask(loader: *FileLoader, fileName: []const u8, libFile: ?*LibFile, includeReason: *FileIncludeReason) void {
    _ = loader;
    _ = fileName;
    _ = libFile;
    _ = includeReason;
    @panic("Not implemented");
}

pub fn addAutomaticTypeDirectiveTasks(loader: *FileLoader) void {
    _ = loader;
    @panic("Not implemented");
}

pub fn resolveAutomaticTypeDirectives(loader: *FileLoader, containingFileName: []const u8) void {
    _ = loader;
    _ = containingFileName;
    @panic("Not implemented");
}

pub fn addProjectReferenceTasks(loader: *FileLoader, singleThreaded: bool) void {
    _ = loader;
    _ = singleThreaded;
    @panic("Not implemented");
}

pub fn sortLibs(loader: *FileLoader, libFiles: []ast.NodeIndex) void {
    _ = loader;
    _ = libFiles;
    @panic("Not implemented");
}

pub fn getDefaultLibFilePriority(loader: *FileLoader, a: ast.NodeIndex) i32 {
    _ = loader;
    _ = a;
    @panic("Not implemented");
}

pub fn loadSourceFileMetaData(loader: *FileLoader, fileName: []const u8) ast.SourceFileMetaData {
    _ = loader;
    _ = fileName;
    @panic("Not implemented");
}

pub fn parseSourceFile(loader: *FileLoader, t: *parseTask) ast.NodeIndex {
    _ = loader;
    _ = t;
    @panic("Not implemented");
}

pub fn isSupportedExtension(loader: *FileLoader, canonicalFileName: []const u8) bool {
    _ = loader;
    _ = canonicalFileName;
    @panic("Not implemented");
}

pub fn getSourceFileFromReference(
    loader: *FileLoader,
    fileName: []const u8,
    referenceText: []const u8,
    containingFile: []const u8,
    includeReason: *FileIncludeReason,
) void {
    _ = loader;
    _ = fileName;
    _ = referenceText;
    _ = containingFile;
    _ = includeReason;
    @panic("Not implemented");
}

pub fn resolveTripleslashPathReference(loader: *FileLoader, moduleName: []const u8, containingFile: []const u8, index: usize) void {
    _ = loader;
    _ = moduleName;
    _ = containingFile;
    _ = index;
    @panic("Not implemented");
}

pub fn resolveTypeReferenceDirectives(loader: *FileLoader, t: *parseTask) void {
    _ = loader;
    _ = t;
    @panic("Not implemented");
}

pub fn resolveImportsAndModuleAugmentations(loader: *FileLoader, t: *parseTask) void {
    _ = loader;
    _ = t;
    @panic("Not implemented");
}

pub fn createSyntheticImport(loader: *FileLoader, text: []const u8, file: ast.NodeIndex) ast.NodeIndex {
    _ = loader;
    _ = text;
    _ = file;
    @panic("Not implemented");
}

pub fn pathForLibFile(loader: *FileLoader, name: []const u8) *LibFile {
    _ = loader;
    _ = name;
    @panic("Not implemented");
}

pub fn resolveLibrary(loader: *FileLoader, libraryName: []const u8, resolveFrom: []const u8) void {
    _ = loader;
    _ = libraryName;
    _ = resolveFrom;
    @panic("Not implemented");
}

pub fn getLibraryNameFromLibFileName(libFileName: []const u8) []const u8 {
    _ = libFileName;
    @panic("Not implemented");
}

pub fn getInferredLibraryNameResolveFrom(options: *core.CompilerOptions, currentDirectory: []const u8, libFileName: []const u8) []const u8 {
    _ = options;
    _ = currentDirectory;
    _ = libFileName;
    @panic("Not implemented");
}

pub fn getModeForTypeReferenceDirectiveInFile(ref: *ast.FileReference, file: ast.NodeIndex, meta: ast.SourceFileMetaData, options: *core.CompilerOptions) core.ResolutionMode {
    _ = ref;
    _ = file;
    _ = meta;
    _ = options;
    @panic("Not implemented");
}

pub fn getDefaultResolutionModeForFile(fileName: []const u8, meta: ast.SourceFileMetaData, options: *core.CompilerOptions) core.ResolutionMode {
    _ = fileName;
    _ = meta;
    _ = options;
    @panic("Not implemented");
}

pub fn getModeForUsageLocation(fileName: []const u8, meta: ast.SourceFileMetaData, usage: ast.NodeIndex, options: *core.CompilerOptions) core.ResolutionMode {
    _ = fileName;
    _ = meta;
    _ = usage;
    _ = options;
    @panic("Not implemented");
}

pub fn importSyntaxAffectsModuleResolution(options: *core.CompilerOptions) bool {
    _ = options;
    @panic("Not implemented");
}

pub fn getEmitSyntaxForUsageLocationWorker(fileName: []const u8, meta: ast.SourceFileMetaData, usage: ast.NodeIndex, options: *core.CompilerOptions) core.ResolutionMode {
    _ = fileName;
    _ = meta;
    _ = usage;
    _ = options;
    @panic("Not implemented");
}
