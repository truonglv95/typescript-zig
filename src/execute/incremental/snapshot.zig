const std = @import("std");

//! Program snapshot for incremental compilation.
//!
//! Port of `internal/execute/incremental/snapshot.go` (440 LOC).
//!
//! A `Snapshot` captures the state of a program after a build, including
//! file versions, signatures, and emit state. It is used to:
//! 1. Compare against the next build to detect changes
//! 2. Serialize to/from `.tsbuildinfo` files

const core = @import("../../core/core.zig");

/// File info — version, signature, and metadata for a single source file.
/// Port of Go's `FileInfo`.
pub const FileInfo = struct {
    version: []const u8 = "",
    signature: []const u8 = "",
    affects_global_scope: bool = false,
    implied_node_format: u32 = 0,

    pub fn getVersion(self: FileInfo) []const u8 {
        return self.version;
    }

    pub fn getSignature(self: FileInfo) []const u8 {
        return self.signature;
    }

    pub fn getAffectsGlobalScope(self: FileInfo) bool {
        return self.affects_global_scope;
    }

    pub fn getImpliedNodeFormat(self: FileInfo) u32 {
        return self.implied_node_format;
    }
};

/// What kind of emit is needed for a file. Bitmask.
/// Port of Go's `FileEmitKind`.
pub const FileEmitKind = struct {
    pub const None: u32 = 0;
    pub const Js: u32 = 1 << 0;
    pub const JsMap: u32 = 1 << 1;
    pub const JsInlineMap: u32 = 1 << 2;
    pub const DtsErrors: u32 = 1 << 3;
    pub const DtsEmit: u32 = 1 << 4;
    pub const DtsMap: u32 = 1 << 5;

    pub const Dts: u32 = DtsErrors | DtsEmit;
    pub const AllJs: u32 = Js | JsMap | JsInlineMap;
    pub const AllDtsEmit: u32 = DtsEmit | DtsMap;
    pub const AllDts: u32 = Dts | DtsMap;
    pub const All: u32 = AllJs | AllDts;
};

/// Computes a hash of the given text for file version tracking.
/// Port of Go's `ComputeHash` (uses xxh3 in Go, FNV-1a in Zig for simplicity).
pub fn computeHash(text: []const u8, hash_with_text: bool) []const u8 {
    // FNV-1a 64-bit hash.
    var hash: u64 = 14695981039346656037;
    for (text) |byte| {
        hash = (hash ^ byte) *% 1099511628211;
    }
    // Format as hex.
    var buf: [16]u8 = undefined;
    _ = std.fmt.bufPrint(&buf, "{x:0>16}", .{hash}) catch return "";
    if (hash_with_text) {
        // Would need allocation to concatenate; return hash only for now.
        return buf[0..16];
    }
    return buf[0..16];
}

/// Program snapshot — captures the state of a program after a build.
/// Port of Go's `Snapshot`.
pub const Snapshot = struct {
    /// File names in the program.
    file_names: []const []const u8 = &.{},
    /// File info (version, signature) for each file.
    file_infos: []const FileInfo = &.{},
    /// Root file IDs (indices into file_names).
    root: struct { start: i32 = 0, end: i32 = 0 } = .{},
    /// Whether the build had errors.
    has_errors: bool = false,
    /// Whether semantic check is pending.
    check_pending: bool = false,
    /// Files that changed since last build (indices).
    change_file_set: []const i32 = &.{},
    /// Files pending emit (indices).
    affected_files_pending_emit: []const i32 = &.{},
    /// Per-file emit diagnostics state.
    emit_diagnostics_per_file: []const i32 = &.{},
    /// Per-file semantic diagnostics state.
    semantic_diagnostics_per_file: []const i32 = &.{},

    /// Returns the file info for the given file name, or null if not found.
    pub fn getFileInfo(self: Snapshot, file_name: []const u8) ?FileInfo {
        for (self.file_names, 0..) |name, i| {
            if (i < self.file_infos.len and std.mem.eql(u8, name, file_name)) {
                return self.file_infos[i];
            }
        }
        return null;
    }

    /// Returns true if any files are pending emit.
    pub fn hasPendingEmit(self: Snapshot) bool {
        return self.affected_files_pending_emit.len > 0;
    }

    /// Returns true if the snapshot has changed files.
    pub fn hasChangedFiles(self: Snapshot) bool {
        return self.change_file_set.len > 0;
    }
};
