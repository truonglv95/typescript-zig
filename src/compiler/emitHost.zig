const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const core = @import("../core/core.zig");
const module = @import("../module/module.zig");
const outputpaths = @import("../outputpaths/outputpaths.zig");
const packagejson = @import("../packagejson/packagejson.zig");
const printer = @import("../printer/printer.zig");
const symlinks = @import("../symlinks/symlinks.zig");
const declarations = @import("../transformers/declarations.zig");
const tsoptions = @import("../tsoptions/tsoptions.zig");
const tspath = @import("../tspath/tspath.zig");
const program_module = @import("program.zig");
const emitresolver = @import("../printer/emitresolver.zig");

pub const EmitHost = struct {
    program: *program_module.Program,
    emitResolver: *emitresolver.EmitResolver,

    pub fn init(program: *program_module.Program, emitResolver: *emitresolver.EmitResolver) EmitHost {
        return .{
            .program = program,
            .emitResolver = emitResolver,
        };
    }

    pub fn getModeForUsageLocation(self: *EmitHost, file: ast_gen.NodeIndex, moduleSpecifier: ast_gen.NodeIndex) core.ResolutionMode {
        return self.program.getModeForUsageLocation(file, moduleSpecifier);
    }

    pub fn getResolvedModuleFromModuleSpecifier(self: *EmitHost, file: ast_gen.NodeIndex, moduleSpecifier: ast_gen.NodeIndex) ?*module.ResolvedModule {
        return self.program.getResolvedModuleFromModuleSpecifier(file, moduleSpecifier);
    }

    pub fn getDefaultResolutionModeForFile(self: *EmitHost, file: ast_gen.NodeIndex) core.ResolutionMode {
        return self.program.getDefaultResolutionModeForFile(file);
    }

    pub fn getEmitModuleFormatOfFile(self: *EmitHost, file: ast_gen.NodeIndex) core.ModuleKind {
        return self.program.getEmitModuleFormatOfFile(file);
    }

    pub fn fileExists(self: *EmitHost, path: []const u8) bool {
        return self.program.fileExists(path);
    }

    pub fn getGlobalTypingsCacheLocation(self: *EmitHost) []const u8 {
        return self.program.getGlobalTypingsCacheLocation();
    }

    pub fn getNearestAncestorDirectoryWithPackageJson(self: *EmitHost, dirname: []const u8) []const u8 {
        return self.program.getNearestAncestorDirectoryWithPackageJson(dirname);
    }

    pub fn getPackageJsonInfo(self: *EmitHost, pkgJsonPath: []const u8) ?*packagejson.InfoCacheEntry {
        return self.program.getPackageJsonInfo(pkgJsonPath);
    }

    pub fn getSourceOfProjectReferenceIfOutputIncluded(self: *EmitHost, file: ast_gen.NodeIndex) []const u8 {
        return self.program.getSourceOfProjectReferenceIfOutputIncluded(file);
    }

    pub fn getProjectReferenceFromSource(self: *EmitHost, path: tspath.Path) ?*tsoptions.SourceOutputAndProjectReference {
        return self.program.getProjectReferenceFromSource(path);
    }

    pub fn getRedirectTargets(self: *EmitHost, path: tspath.Path) [][]const u8 {
        return self.program.getRedirectTargets(path);
    }

    pub fn getEffectiveDeclarationFlags(self: *EmitHost, node: ast_gen.NodeIndex, flags: ast.ModifierFlags) ast.ModifierFlags {
        return self.getEmitResolver().getEffectiveDeclarationFlags(node, flags);
    }

    pub fn getOutputPathsFor(self: *EmitHost, file: ast_gen.NodeIndex, forceDtsPaths: bool) declarations.OutputPaths {
        return outputpaths.getOutputPathsFor(file, self.options(), self, forceDtsPaths);
    }

    pub fn getResolutionModeOverride(self: *EmitHost, node: ast_gen.NodeIndex) core.ResolutionMode {
        return self.getEmitResolver().getResolutionModeOverride(node);
    }

    pub fn getSourceFileFromReference(self: *EmitHost, origin: ast_gen.NodeIndex, ref: ast_gen.NodeIndex) ast_gen.NodeIndex {
        return self.program.getSourceFileFromReference(origin, ref);
    }

    pub fn options(self: *EmitHost) *core.CompilerOptions {
        return &self.program.opts.options;
    }

    pub fn sourceFiles(self: *EmitHost) []const u32 {
        return self.program.getSourceFiles();
    }

    pub fn getCurrentDirectory(self: *EmitHost) []const u8 {
        return self.program.getCurrentDirectory();
    }

    pub fn commonSourceDirectory(self: *EmitHost) []const u8 {
        return self.program.commonSourceDirectory();
    }

    pub fn useCaseSensitiveFileNames(self: *EmitHost) bool {
        return self.program.useCaseSensitiveFileNames();
    }

    pub fn isEmitBlocked(self: *EmitHost, file: []const u8) bool {
        return self.program.isEmitBlocked(file);
    }

    pub fn writeFile(self: *EmitHost, fileName: []const u8, text: []const u8) anyerror!void {
        return self.program.host.fs.writeFile(fileName, text);
    }

    pub fn getEmitResolver(self: *EmitHost) *emitresolver.EmitResolver {
        return self.emitResolver;
    }

    pub fn isSourceFileFromExternalLibrary(self: *EmitHost, file: ast_gen.NodeIndex) bool {
        return self.program.isSourceFileFromExternalLibrary(file);
    }

    pub fn getSymlinkCache(self: *EmitHost) ?*symlinks.KnownSymlinks {
        return self.program.getSymlinkCache();
    }

    pub fn resolveModuleName(self: *EmitHost, moduleName: []const u8, containingFile: []const u8, resolutionMode: core.ResolutionMode) ?*module.ResolvedModule {
        if (self.program.resolver) |resolver| {
            return resolver.resolveModuleName(moduleName, containingFile, resolutionMode, null);
        }
        return null;
    }
};
