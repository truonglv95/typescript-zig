const std = @import("std");
const collections = @import("../collections/collections.zig");
const compiler = @import("../compiler/program.zig");
const core = @import("../core/core.zig");
const tsoptions = @import("../tsoptions/tsoptions.zig");
const tspath = @import("../tspath/tspath.zig");
const ast = @import("../ast/ast.zig");
// We skip specific ata, ls, logging references for now and mock if needed
// const ata = @import("ata.zig");
// const logging = @import("logging.zig");

pub const client = @import("client.zig");
pub const WatcherID = client.WatcherID;
pub const FileSystemWatcher = client.FileSystemWatcher;
pub const PublishDiagnosticsParams = client.PublishDiagnosticsParams;
pub const TelemetryEvent = client.TelemetryEvent;
pub const Client = client.Client;

pub const inferredProjectName = "/dev/null/inferred";
pub const hr = "-----------------------------------------------";

pub const Kind = enum { Inferred, Configured };

pub const ProgramUpdateKind = enum { None, Cloned, SameFileNames, NewFiles };

pub const PendingReload = enum { None, FileNames, Full };

// Forward declarations for types we will implement later
pub const CompilerHost = opaque {};
pub const ProjectCollectionBuilder = opaque {};
pub const LogTree = opaque {};
pub const WatchedFiles = opaque {};
pub const CheckerPool = opaque {};
pub const TypingsInfo = opaque {};

pub const Project = struct {
    kind: Kind,
    currentDirectory: []const u8,
    configFileName: []const u8,
    configFilePath: tspath.Path,

    dirty: bool,
    dirtyFilePath: tspath.Path,

    host: ?*CompilerHost = null,
    CommandLine: ?*tsoptions.ParsedCommandLine = null,
    commandLineWithTypingsFiles: ?*tsoptions.ParsedCommandLine = null,
    commandLineWithTypingsFilesOnce: bool = false,
    
    // We mock Program type with a void pointer or use compiler.Program if available
    Program: ?*compiler.Program = null,
    ProgramUpdateKind: ProgramUpdateKind = .None,
    ProgramLastUpdate: u64 = 0,
    
    potentialProjectReferences: ?*std.StringHashMap(void) = null,

    programFilesWatch: ?*WatchedFiles = null,
    typingsWatch: ?*WatchedFiles = null,

    checkerPool: ?*CheckerPool = null,

    installedTypingsInfo: ?*TypingsInfo = null,
    typingsFiles: [][]const u8 = &[_][]const u8{},

    pub fn newConfiguredProject(
        allocator: std.mem.Allocator,
        configFileName: []const u8,
        configFilePath: tspath.Path,
        builder: *ProjectCollectionBuilder,
        logger: ?*LogTree,
    ) !*Project {
        _ = configFilePath;
        _ = builder;
        return newProject(allocator, configFileName, .Configured, tspath.getDirectoryPath(allocator, configFileName) catch configFileName, logger);
    }

    pub fn newInferredProject(
        allocator: std.mem.Allocator,
        currentDirectory: []const u8,
        compilerOptions: ?*core.CompilerOptions,
        rootFileNames: [][]const u8,
        builder: *ProjectCollectionBuilder,
        logger: ?*LogTree,
    ) !*Project {
        _ = compilerOptions;
        _ = rootFileNames;
        _ = builder;
        const p = try newProject(allocator, inferredProjectName, .Inferred, currentDirectory, logger);
        // We skip full CommandLine parsing for now
        return p;
    }

    pub fn newProject(
        allocator: std.mem.Allocator,
        configFileName: []const u8,
        kind: Kind,
        currentDirectory: []const u8,
        logger: ?*LogTree,
    ) !*Project {
        _ = logger;
        const p = try allocator.create(Project);
        p.* = Project{
            .configFileName = configFileName,
            .kind = kind,
            .currentDirectory = currentDirectory,
            .dirty = true,
            .configFilePath = "", // to be evaluated
            .dirtyFilePath = "",
        };
        return p;
    }

    pub fn name(self: *const Project) []const u8 {
        return self.configFileName;
    }

    pub fn displayName(self: *const Project, cwd: []const u8) []const u8 {
        _ = cwd;
        if (self.kind == .Inferred) {
            // Need a getBaseFileName implementation, mock for now
            return self.currentDirectory; 
        }
        return self.configFileName;
    }

    pub fn id(self: *const Project) tspath.Path {
        return self.configFilePath;
    }

    pub fn getConfigFileName(self: *const Project) []const u8 {
        if (self.kind != .Configured) @panic("ConfigFileName called on non-configured project");
        return self.configFileName;
    }

    pub fn getConfigFilePath(self: *const Project) tspath.Path {
        if (self.kind != .Configured) @panic("ConfigFilePath called on non-configured project");
        return self.configFilePath;
    }

    pub fn getProgram(self: *const Project) ?*compiler.Program {
        return self.Program;
    }

    pub fn hasFile(self: *const Project, fileName: []const u8) bool {
        _ = self;
        _ = fileName;
        return false; // stub
    }

    pub fn containsFile(self: *const Project, path: tspath.Path) bool {
        _ = self;
        _ = path;
        return false; // stub
    }

    pub fn isSourceFromProjectReference(self: *const Project, path: tspath.Path) bool {
        _ = self;
        _ = path;
        return false; // stub
    }

    pub fn clone(self: *const Project, allocator: std.mem.Allocator) !*Project {
        var p = try allocator.create(Project);
        p.* = self.*;
        // ProgramUpdateKind None
        p.ProgramUpdateKind = .None;
        return p;
    }

    pub fn setCommandLine(self: *Project, commandLine: *tsoptions.ParsedCommandLine) void {
        self.CommandLine = commandLine;
        self.commandLineWithTypingsFiles = null;
        self.commandLineWithTypingsFilesOnce = .{};
        self.potentialProjectReferences = null;
        self.dirty = true;
        self.dirtyFilePath = "";
    }

    pub fn setPotentialProjectReference(self: *Project, configFilePath: tspath.Path) void {
        _ = self;
        _ = configFilePath;
        // stub
    }
};

pub const CreateProgramResult = struct {
    program: ?*compiler.Program,
    updateKind: ProgramUpdateKind,
};

