const std = @import("std");
const commandlineoption = @import("commandlineoption.zig");

//! Type acquisition command-line option declarations.
//!
//! Port of `internal/tsoptions/declstypeacquisition.go` (29 LOC).
//!
//! Defines the `typeAcquisition` object option and its sub-options:
//! `enable`, `include`, `exclude`, `disableFilenameBasedTypeAcquisition`.

const CommandLineOption = commandlineoption.CommandLineOption;
const CommandLineOptionKind = commandlineoption.CommandLineOptionKind;

/// Sub-options of the `typeAcquisition` tsconfig object.
pub const type_acquisition_decls = [_]CommandLineOption{
    .{
        .name = "enable",
        .shortName = "",
        .kind = .Boolean,
        .isFilePath = false,
        .isTSConfigOnly = false,
        .isCommandLineOnly = false,
        .showInSimplifiedHelpView = false,
        .affectsDeclarationPath = false,
        .affectsProgramStructure = false,
        .affectsSemanticDiagnostics = false,
        .affectsBuildInfo = false,
        .affectsBindDiagnostics = false,
        .affectsSourceFile = false,
        .affectsModuleResolution = false,
        .affectsEmit = false,
    },
    .{
        .name = "include",
        .shortName = "",
        .kind = .List,
        .isFilePath = false,
        .isTSConfigOnly = false,
        .isCommandLineOnly = false,
        .showInSimplifiedHelpView = false,
        .affectsDeclarationPath = false,
        .affectsProgramStructure = false,
        .affectsSemanticDiagnostics = false,
        .affectsBuildInfo = false,
        .affectsBindDiagnostics = false,
        .affectsSourceFile = false,
        .affectsModuleResolution = false,
        .affectsEmit = false,
    },
    .{
        .name = "exclude",
        .shortName = "",
        .kind = .List,
        .isFilePath = false,
        .isTSConfigOnly = false,
        .isCommandLineOnly = false,
        .showInSimplifiedHelpView = false,
        .affectsDeclarationPath = false,
        .affectsProgramStructure = false,
        .affectsSemanticDiagnostics = false,
        .affectsBuildInfo = false,
        .affectsBindDiagnostics = false,
        .affectsSourceFile = false,
        .affectsModuleResolution = false,
        .affectsEmit = false,
    },
    .{
        .name = "disableFilenameBasedTypeAcquisition",
        .shortName = "",
        .kind = .Boolean,
        .isFilePath = false,
        .isTSConfigOnly = false,
        .isCommandLineOnly = false,
        .showInSimplifiedHelpView = false,
        .affectsDeclarationPath = false,
        .affectsProgramStructure = false,
        .affectsSemanticDiagnostics = false,
        .affectsBuildInfo = false,
        .affectsBindDiagnostics = false,
        .affectsSourceFile = false,
        .affectsModuleResolution = false,
        .affectsEmit = false,
    },
};
