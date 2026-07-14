const std = @import("std");
const ast = @import("../ast/pkg.zig");
const diagnostics = @import("../diagnostics/pkg.zig");
const module = @import("../module/pkg.zig");
const scanner = @import("../scanner/pkg.zig");
const tsoptions = @import("../tsoptions/pkg.zig");
const tspath = @import("../tspath/pkg.zig");

// Assuming Program is accessible
const Program = @import("program.zig").Program;

pub const FileIncludeKind = enum(u8) {
    Import = 0,
    ReferenceFile,
    TypeReferenceDirective,
    LibReferenceDirective,

    RootFile,
    LibFile,
    AutomaticTypeDirectiveFile,
};

pub const ReferencedFileData = struct {
    file: tspath.Path,
    index: u32,
    synthetic: ast.NodeIndex,
};

pub const AutomaticTypeDirectiveFileData = struct {
    typeReference: []const u8,
    packageId: module.PackageId,
};

pub const FileIncludeReason = struct {
    kind: FileIncludeKind,
    data: union(enum) {
        index: u32,
        referencedFileData: *ReferencedFileData,
        automaticTypeDirectiveFileData: *AutomaticTypeDirectiveFileData,
    },

    relativeFileNameDiag: ?ast.DiagnosticIndex = null,
    relativeFileNameDiagOnce: std.once = std.once.init(),

    diag: ?ast.DiagnosticIndex = null,
    diagOnce: std.once = std.once.init(),

    pub fn asIndex(self: FileIncludeReason) u32 {
        return self.data.index;
    }

    pub fn asLibFileIndex(self: FileIncludeReason) ?u32 {
        return switch (self.data) {
            .index => |idx| idx,
            else => null,
        };
    }

    pub fn isReferencedFile(self: *const FileIncludeReason) bool {
        return @intFromEnum(self.kind) <= @intFromEnum(FileIncludeKind.LibReferenceDirective);
    }

    pub fn asReferencedFileData(self: FileIncludeReason) *ReferencedFileData {
        return self.data.referencedFileData;
    }

    pub fn asAutomaticTypeDirectiveFileData(self: FileIncludeReason) *AutomaticTypeDirectiveFileData {
        return self.data.automaticTypeDirectiveFileData;
    }
};

pub const ReferenceFileLocation = struct {
    file: ast.SourceFileIndex,
    node: ast.NodeIndex,
    ref: ast.FileReferenceIndex,
    packageId: module.PackageId,
    isSynthetic: bool,
};
