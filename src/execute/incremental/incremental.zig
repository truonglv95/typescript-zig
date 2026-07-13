const std = @import("std");

//! Build info reader for incremental compilation.
//!
//! Port of `internal/execute/incremental/incremental.go` (56 LOC).
//!
//! Reads `.tsbuildinfo` files and deserializes them into `BuildInfo`
//! structs for incremental compilation.

const compiler = @import("../../compiler/compiler.zig");
const vfs = @import("../../vfs/vfs.zig");

/// Build info reader interface.
/// Port of Go's `BuildInfoReader`.
pub const BuildInfoReader = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        readBuildInfo: *const fn (ptr: *anyopaque, config_file_name: []const u8) ?BuildInfo,
    };

    pub fn readBuildInfo(self: BuildInfoReader, config_file_name: []const u8) ?BuildInfo {
        return self.vtable.readBuildInfo(self.ptr, config_file_name);
    }
};

/// Build info structure (deserialized from .tsbuildinfo).
/// Port of Go's `BuildInfo`. Full struct has many fields; this is a
/// simplified version with the essential fields.
pub const BuildInfo = struct {
    /// Version of the TypeScript compiler that wrote this build info.
    version: []const u8 = "",
    /// Whether this build info is for an incremental build.
    is_incremental: bool = false,
    /// File names included in the program.
    file_names: []const []const u8 = &.{},
    /// Compiler options hash.
    options_hash: u64 = 0,
    /// File hashes for change detection.
    file_hashes: ?std.StringHashMapUnmanaged(u64) = null,

    /// Returns true if the build info version is compatible.
    pub fn isValidVersion(self: BuildInfo) bool {
        return self.version.len > 0;
    }

    /// Returns true if this build info supports incremental compilation.
    pub fn isIncremental(self: BuildInfo) bool {
        return self.is_incremental;
    }
};

/// Creates a build info reader backed by a CompilerHost.
/// Port of Go's `NewBuildInfoReader`.
pub fn createBuildInfoReader(host: compiler.CompilerHost) BuildInfoReader {
    // TODO(phase2.8): wire actual reader with JSON deserialization.
    _ = host;
    return BuildInfoReader{
        .ptr = undefined,
        .vtable = &.{
            .readBuildInfo = readBuildInfoStub,
        },
    };
}

fn readBuildInfoStub(ptr: *anyopaque, config_file_name: []const u8) ?BuildInfo {
    _ = ptr;
    _ = config_file_name;
    return null;
}
