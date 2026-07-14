const std = @import("std");
const ast = @import("../ast/ast.zig");
const core = @import("../core/core.zig");
const diagnostics = @import("../diagnostics/diagnostics.zig");
const commandlineoption = @import("commandlineoption.zig");

// Note: CreateDiagnosticForNodeInSourceFile and CreateDiagnosticForNodeInSourceFileOrCompilerDiagnostic
// will be moved or implemented here. Wait, actually I will implement them as stubs.
// The actual logic is simple but depends on ast.Diagnostic and diagnostics.Message.

pub fn createDiagnosticForInvalidEnumType(
    allocator: std.mem.Allocator,
    opt: *commandlineoption.CommandLineOption,
    sourceFile: ?ast.NodeIndex,
    node: ?ast.NodeIndex,
) !*ast.Diagnostic {
    // optName := "--" + opt.Name
    // return CreateDiagnosticForNodeInSourceFileOrCompilerDiagnostic(sourceFile, node, diagnostics.Argument_for_0_option_must_be_Colon_1, optName, stringNames)
    _ = allocator;
    _ = opt;
    _ = sourceFile;
    _ = node;
    @panic("createDiagnosticForInvalidEnumType not implemented");
}

pub fn createUnknownOptionError(
    allocator: std.mem.Allocator,
    unknownOption: []const u8,
    unknownOptionDiagnostic: *const diagnostics.Message,
    unknownOptionErrorText: ?[]const u8,
    node: ?ast.NodeIndex,
    sourceFile: ?ast.NodeIndex,
    alternateMode: ?*commandlineoption.AlternateModeDiagnostics,
) !*ast.Diagnostic {
    _ = allocator;
    _ = unknownOption;
    _ = unknownOptionDiagnostic;
    _ = unknownOptionErrorText;
    _ = node;
    _ = sourceFile;
    _ = alternateMode;
    @panic("createUnknownOptionError not implemented");
}

pub fn CreateDiagnosticForNodeInSourceFile(
    allocator: std.mem.Allocator,
    sourceFile: ast.NodeIndex,
    node: ast.NodeIndex,
    message: *const diagnostics.Message,
    args: anytype,
) !*ast.Diagnostic {
    _ = allocator;
    _ = sourceFile;
    _ = node;
    _ = message;
    _ = args;
    @panic("CreateDiagnosticForNodeInSourceFile not implemented");
}

pub fn CreateDiagnosticForNodeInSourceFileOrCompilerDiagnostic(
    allocator: std.mem.Allocator,
    sourceFile: ?ast.NodeIndex,
    node: ?ast.NodeIndex,
    message: *const diagnostics.Message,
    args: anytype,
) !*ast.Diagnostic {
    _ = allocator;
    _ = sourceFile;
    _ = node;
    _ = message;
    _ = args;
    @panic("CreateDiagnosticForNodeInSourceFileOrCompilerDiagnostic not implemented");
}

pub fn extraKeyDiagnostics(s: []const u8) *const diagnostics.Message {
    if (std.mem.eql(u8, s, "compilerOptions")) {
        return &diagnostics.Unknown_compiler_option_0;
    } else if (std.mem.eql(u8, s, "watchOptions")) {
        return &diagnostics.Unknown_watch_option_0;
    } else if (std.mem.eql(u8, s, "typeAcquisition")) {
        return &diagnostics.Unknown_type_acquisition_option_0;
    } else if (std.mem.eql(u8, s, "buildOptions")) {
        return &diagnostics.Unknown_build_option_0;
    }
    return &diagnostics.Unknown_option_excludes_value_0;
}
