const std = @import("std");

//! Build info — serialization format for .tsbuildinfo files.
//!
//! Port of `internal/execute/incremental/buildInfo.go` (630 LOC).
//!
//! The `BuildInfo` struct is serialized to a `.tsbuildinfo` file after
//! each incremental build. It contains:
//! - Compiler version
//! - File names and their hashes (for change detection)
//! - Compiler options hash
//! - Incremental state (affected files, pending emit, etc.)
//!
//! On the next build, the build info is read back to determine which
//! files have changed and need to be recompiled.

const core = @import("../../core/core.zig");

/// File ID in the build info (index into the file names array).
pub const BuildInfoFileId = i32;
pub const BuildInfoFileIdListId = i32;

/// Root file info — either a file ID range (incremental) or a string
/// path (non-incremental). Port of Go's `BuildInfoRoot`.
pub const BuildInfoRoot = struct {
    start: BuildInfoFileId = 0,
    end: BuildInfoFileId = 0,
    non_incremental: []const u8 = "",
};

/// File info without signature (for files that don't need signature tracking).
pub const BuildInfoFileInfoNoSignature = struct {
    version: []const u8 = "",
    no_signature: bool = false,
    affects_global_scope: bool = false,
    implied_node_format: u32 = 0,
};

/// File info with signature (for files that need signature tracking).
pub const BuildInfoFileInfo = struct {
    version: []const u8 = "",
    signature: []const u8 = "",
    affects_global_scope: bool = false,
    implied_node_format: u32 = 0,
};

/// Build info program structure. Port of Go's `BuildInfoProgram`.
pub const BuildInfoProgram = struct {
    file_names: []const []const u8 = &.{},
    file_infos: []const BuildInfoFileInfo = &.{},
    root: BuildInfoRoot = .{},
    file_id_list: []const BuildInfoFileId = &.{},
    file_ids_map: ?std.StringHashMapUnmanaged(BuildInfoFileId) = null,
};

/// The full build info structure. Port of Go's `BuildInfo`.
pub const BuildInfo = struct {
    /// TypeScript compiler version that wrote this build info.
    version: []const u8 = "",
    /// Whether this is an incremental build.
    is_incremental: bool = false,
    /// The program state (file names, hashes, etc.).
    program: ?BuildInfoProgram = null,
    /// Whether the build had errors.
    errors: bool = false,
    /// Whether the build had semantic errors.
    semantic_errors: bool = false,
    /// Whether semantic check is pending.
    check_pending: bool = false,
    /// Files that changed since last build.
    change_file_set: ?[]const BuildInfoFileId = null,
    /// Files pending emit.
    affected_files_pending_emit: ?[]const BuildInfoFileId = null,
    /// Per-file emit diagnostics.
    emit_diagnostics_per_file: ?[]const BuildInfoFileId = null,
    /// Per-file semantic diagnostics.
    semantic_diagnostics_per_file: ?[]const BuildInfoFileId = null,

    /// Returns true if the build info version is compatible.
    pub fn isValidVersion(self: BuildInfo) bool {
        return self.version.len > 0;
    }

    /// Returns true if this build info supports incremental compilation.
    pub fn isIncremental(self: BuildInfo) bool {
        return self.is_incremental;
    }

    /// Returns true if there are pending emit files.
    pub fn isEmitPending(self: BuildInfo) bool {
        return self.affected_files_pending_emit != null and self.affected_files_pending_emit.?.len > 0;
    }
};

/// Computes a hash of the given text for file version tracking.
/// Port of Go's `ComputeHash`.
pub fn computeHash(text: []const u8, deterministic: bool) []const u8 {
    _ = deterministic;
    // Use a simple hash for now. Go uses SHA-256.
    // TODO(phase2.8): implement proper SHA-256 hash.
    var hash: u64 = 14695981039346656037; // FNV offset basis
    for (text) |byte| {
        hash = (hash ^ byte) *% 1099511628211; // FNV prime
    }
    // Return a hex string representation.
    // For now, return a static buffer (caller should dupe if needed).
    var buf: [16]u8 = undefined;
    _ = std.fmt.bufPrint(&buf, "{x:0>16}", .{hash}) catch return "";
    return buf[0..16];
}

/// Returns true if the given file name is a build info file.
/// Port of Go's `IsBuildInfoFileName`.
pub fn isBuildInfoFileName(file_name: []const u8) bool {
    return std.mem.endsWith(u8, file_name, ".tsbuildinfo");
}

/// Returns true if the given file name is a default library file
/// referenced in build info.
pub fn isBuildInfoFileNameDefaultLibrary(file_name: []const u8) bool {
    return std.mem.startsWith(u8, file_name, "lib.") and std.mem.endsWith(u8, file_name, ".d.ts");
}
