const std = @import("std");
const core = @import("../core/core.zig");

pub const ResultKind = enum(u8) {
    None = 0,
    NodeModules,
    Paths,
    Redirect,
    Relative,
    Ambient,
};

pub const ModulePath = struct {
    FileName: []const u8,
    IsInNodeModules: bool,
    IsRedirect: bool,
};

pub const ImportModuleSpecifierPreference = enum {
    None,
    Shortest,
    ProjectRelative,
    Relative,
    NonRelative,
};

pub const ImportModuleSpecifierEndingPreference = enum {
    None,
    Auto,
    Minimal,
    Index,
    Js,
};

pub const UserPreferences = struct {
    ImportModuleSpecifierPreference: ImportModuleSpecifierPreference,
    ImportModuleSpecifierEnding: ImportModuleSpecifierEndingPreference,
    AutoImportSpecifierExcludeRegexes: [][]const u8,
};

pub const ModuleSpecifierOptions = struct {
    OverrideImportMode: core.ModuleKind, // core.ResolutionMode
};

pub const RelativePreferenceKind = enum(u8) {
    Relative = 0,
    NonRelative,
    Shortest,
    ExternalNonRelative,
};

pub const ModuleSpecifierEnding = enum(u8) {
    Minimal = 0,
    Index,
    JsExtension,
    TsExtension,
};

pub const MatchingMode = enum(u8) {
    Exact = 0,
    Directory,
    Pattern,
};
