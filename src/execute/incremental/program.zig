const std = @import("std");

//! Incremental program — wraps a compiler.Program with incremental state.
//!
//! Port of `internal/execute/incremental/program.go` (453 LOC).
//!
//! The incremental program tracks changes between builds:
//! - Which files changed (by comparing file versions/hashes)
//! - Which files need re-emission
//! - Which files have pending diagnostics
//!
//! On each build, a new `Program` is created from the current
//! `compiler.Program` and the previous `Program`'s snapshot.

const snapshot = @import("snapshot.zig");
const host_mod = @import("host.zig");
const compiler = @import("../../compiler/compiler.zig");
const core = @import("../../core/core.zig");
const diagnostics = @import("../../diagnostics/diagnostics.zig");

/// How a file's signature was updated.
pub const SignatureUpdateKind = enum(u8) {
    ComputedDts,
    StoredAtEmit,
    UsedVersion,
};

/// Testing data for incremental program diagnostics.
pub const TestingData = struct {
    semantic_diagnostics_per_file: ?*std.StringHashMapUnmanaged(DiagnosticsOrBuildInfoDiagnosticsWithFileName) = null,
    old_program_semantic_diagnostics_per_file: ?*std.StringHashMapUnmanaged(DiagnosticsOrBuildInfoDiagnosticsWithFileName) = null,
    updated_signature_kinds: std.StringHashMapUnmanaged(SignatureUpdateKind) = .empty,
};

/// Diagnostics or build info diagnostics with file name.
pub const DiagnosticsOrBuildInfoDiagnosticsWithFileName = struct {
    file_name: []const u8,
    diagnostics: []const diagnostics.Diagnostic = &.{},
};

/// Incremental program — wraps compiler.Program with change tracking.
/// Port of Go's `incremental.Program`.
pub const Program = struct {
    snapshot: snapshot.Snapshot = .{},
    // program: *compiler.Program, -- TODO: wire when compiler.Program is ready
    host: ?host_mod.Host = null,
    testing_data: ?TestingData = null,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Program {
        return .{ .allocator = allocator };
    }

    /// Creates a new incremental program from the current compiler program
    /// and the previous incremental program.
    /// Port of Go's `NewProgram`.
    pub fn newProgram(
        allocator: std.mem.Allocator,
        // program: *compiler.Program,
        old_program: ?*Program,
        host: host_mod.Host,
        testing: bool,
    ) *Program {
        const prog = allocator.create(Program) catch unreachable;
        prog.* = .{
            .allocator = allocator,
            .host = host,
        };

        // Compute snapshot by comparing current program with old program.
        // TODO(phase2.8): wire programToSnapshot.
        prog.snapshot = .{};

        if (testing) {
            prog.testing_data = TestingData{};
        }

        _ = old_program;
        return prog;
    }

    /// Returns true if any .d.ts files changed in this build.
    /// Port of Go's `HasChangedDtsFile`.
    pub fn hasChangedDtsFile(self: *const Program) bool {
        // TODO(phase2.8): track which changed files are .d.ts files.
        _ = self;
        return false;
    }

    /// Returns the package.json lookup paths used by this program.
    /// Port of Go's `PackageJsonLookupPaths`.
    pub fn packageJsonLookupPaths(self: *const Program) []const []const u8 {
        _ = self;
        return &.{};
    }

    /// Returns the file names in the program.
    pub fn getFileNames(self: *const Program) []const []const u8 {
        return self.snapshot.file_names;
    }

    /// Returns the file info for a given file name.
    pub fn getFileInfo(self: *const Program, file_name: []const u8) ?snapshot.FileInfo {
        return self.snapshot.getFileInfo(file_name);
    }

    /// Returns true if the program has pending emit files.
    pub fn hasPendingEmit(self: *const Program) bool {
        return self.snapshot.hasPendingEmit();
    }

    /// Returns true if the program has changed files.
    pub fn hasChangedFiles(self: *const Program) bool {
        return self.snapshot.hasChangedFiles();
    }
};
