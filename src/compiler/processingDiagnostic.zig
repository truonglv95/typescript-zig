const std = @import("std");
const ast = @import("../ast/pkg.zig");
const collections = @import("../collections/pkg.zig");
const core = @import("../core/pkg.zig");
const diagnostics = @import("../diagnostics/pkg.zig");
const tsoptions = @import("../tsoptions/pkg.zig");
const tspath = @import("../tspath/pkg.zig");

const Program = @import("program.zig").Program;
const FileIncludeReason = @import("fileInclude.zig").FileIncludeReason;

pub const ProcessingDiagnosticKind = enum(u8) {
    UnknownReference,
    ExplainingFileInclude,
};

pub const IncludeExplainingDiagnostic = struct {
    file: tspath.Path,
    diagnosticReason: ?*FileIncludeReason,
    message: *diagnostics.Message,
    args: [][]const u8,
};

pub const ProcessingDiagnostic = struct {
    kind: ProcessingDiagnosticKind,
    data: union(enum) {
        fileIncludeReason: *FileIncludeReason,
        includeExplainingDiagnostic: *IncludeExplainingDiagnostic,
    },

    pub fn asFileIncludeReason(self: ProcessingDiagnostic) *FileIncludeReason {
        return self.data.fileIncludeReason;
    }

    pub fn asIncludeExplainingDiagnostic(self: ProcessingDiagnostic) *IncludeExplainingDiagnostic {
        return self.data.includeExplainingDiagnostic;
    }

    pub fn toDiagnostic(self: *ProcessingDiagnostic, program: *Program) ?ast.DiagnosticIndex {
        _ = self;
        _ = program;
        return null;
    }

    pub fn createDiagnosticExplainingFile(self: *ProcessingDiagnostic, program: *Program) ?ast.DiagnosticIndex {
        _ = self;
        _ = program;
        return null;
    }
};
