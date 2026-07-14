const std = @import("std");
const ast = @import("../ast/pkg.zig");
const collections = @import("../collections/pkg.zig");
const core = @import("../core/pkg.zig");
const module = @import("../module/pkg.zig");
const tsoptions = @import("../tsoptions/pkg.zig");
const tspath = @import("../tspath/pkg.zig");

const FileLoader = @import("filesparser.zig").FileLoader;
const ProgramOptions = @import("program.zig").ProgramOptions;

pub const ProjectReferenceFileMapper = struct {
    opts: ProgramOptions,
    host: module.ResolutionHost,
    loader: ?*FileLoader, // Only present during populating the mapper and parsing, released after that

    configToProjectReference: std.AutoHashMap(tspath.Path, *tsoptions.ParsedCommandLine),
    referencesInConfigFile: std.AutoHashMap(tspath.Path, []tspath.Path),
    sourceToProjectReference: std.AutoHashMap(tspath.Path, *tsoptions.SourceOutputAndProjectReference),
    outputDtsToProjectReference: std.AutoHashMap(tspath.Path, *tsoptions.SourceOutputAndProjectReference),

    // Store all the realpath from dts in node_modules to source file from project reference needed during parsing so it can be used later
    realpathDtsToSource: collections.SyncMap(tspath.Path, *tsoptions.SourceOutputAndProjectReference),
};
