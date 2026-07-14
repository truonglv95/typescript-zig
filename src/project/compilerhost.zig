const std = @import("std");
const ast = @import("../ast/ast.zig");
const compiler = @import("../compiler/program.zig");
const diagnostics = @import("../diagnostics/diagnostics.zig");
const locale = @import("../locale/locale.zig");
const tsoptions = @import("../tsoptions/tsoptions.zig");
const tspath = @import("../tspath/tspath.zig");
const project = @import("project.zig");
const session = @import("session.zig");

pub const SourceFS = opaque {};
pub const ConfigFileRegistry = opaque {};
pub const ProjectCollectionBuilder = opaque {};

pub const CompilerHost = struct {
    configFilePath: tspath.Path,
    currentDirectory: []const u8,
    sessionOptions: *session.SessionOptions,

    sourceFS: ?*SourceFS = null,
    configFileRegistry: ?*ConfigFileRegistry = null,

    proj: ?*project.Project = null,
    builder: ?*ProjectCollectionBuilder = null,
    logger: ?*project.LogTree = null,

    pub fn init(
        allocator: std.mem.Allocator,
        currentDirectory: []const u8,
        proj: *project.Project,
        builder: *ProjectCollectionBuilder,
        logger: ?*project.LogTree,
        sessionOptions: *session.SessionOptions,
    ) !*CompilerHost {
        var host = try allocator.create(CompilerHost);
        host.* = .{
            .configFilePath = proj.configFilePath,
            .currentDirectory = currentDirectory,
            .sessionOptions = sessionOptions,
            .proj = proj,
            .builder = builder,
            .logger = logger,
        };
        return host;
    }

    pub fn freeze(self: *CompilerHost, snapshotFS: *anyopaque, configFileRegistry: *ConfigFileRegistry) void {
        _ = snapshotFS;
        if (self.builder == null) @panic("freeze can only be called once");
        
        // self.sourceFS.source = snapshotFS;
        // self.sourceFS.disableTracking();
        self.configFileRegistry = configFileRegistry;
        self.builder = null;
        self.proj = null;
        self.logger = null;
    }

    pub fn ensureAlive(self: *CompilerHost) void {
        if (self.builder == null or self.proj == null) {
            @panic("method must not be called after snapshot initialization");
        }
    }

    pub fn defaultLibraryPath(self: *CompilerHost) []const u8 {
        return self.sessionOptions.defaultLibraryPath;
    }

    pub fn getFS(self: *CompilerHost) ?*SourceFS {
        return self.sourceFS;
    }

    pub fn getCurrentDirectory(self: *CompilerHost) []const u8 {
        return self.currentDirectory;
    }

    pub fn getResolvedProjectReference(self: *CompilerHost, fileName: []const u8, path: tspath.Path) ?*tsoptions.ParsedCommandLine {
        _ = fileName;
        _ = path;
        if (self.builder == null) {
            // return self.configFileRegistry.getConfig(path);
            return null;
        } else {
            // self.sourceFS.track(fileName);
            // return self.builder.configFileRegistryBuilder.acquireConfigForProject(...)
            return null;
        }
    }

    pub fn getSourceFile(self: *CompilerHost, opts: ast.SourceFileParseOptions) ?*ast.SourceFile {
        self.ensureAlive();
        _ = opts;
        // if (self.sourceFS.getFileByPath(...)) {
        //     const key = newParseCacheKey(...);
        //     return self.builder.parseCache.acquire(key, fh);
        // }
        return null;
    }

    pub fn trace(self: *CompilerHost, msg: *diagnostics.DiagnosticMessage, args: [][]const u8) void {
        _ = self;
        _ = msg;
        _ = args;
        // self.logger.log(msg.localize(locale.Default, args...));
    }
};
