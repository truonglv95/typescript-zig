const std = @import("std");

//! Build orchestrator host.
//!
//! Port of `internal/execute/build/host.go` (122 LOC).
//!
//! Wraps a `compiler.CompilerHost` with build-specific caching:
//! - Caches dts/json source files (reused across build cycles)
//! - Caches resolved project references
//! - Caches extended config files
//! - Tracks per-file config parse times

const compiler = @import("../../compiler/compiler.zig");
const tsoptions = @import("../../tsoptions/tsoptions.zig");
const vfs = @import("../../vfs/vfs.zig");

/// Build host — wraps CompilerHost with build-specific caches.
/// Port of Go's `build.host`.
pub const Host = struct {
    inner: compiler.CompilerHost,
    allocator: std.mem.Allocator,

    // Caches that last only for a build cycle, then cleared.
    // TODO(phase2.7): wire parseCache for source files + extended configs.

    // Caches that persist across build cycles.
    // TODO(phase2.7): wire parseCache for resolved references + mTimes.

    pub fn init(allocator: std.mem.Allocator, inner: compiler.CompilerHost) Host {
        return .{
            .inner = inner,
            .allocator = allocator,
        };
    }

    pub fn fs(self: *Host) *vfs.FS {
        return self.inner.fs();
    }

    pub fn defaultLibraryPath(self: *Host) []const u8 {
        return self.inner.defaultLibraryPath();
    }

    pub fn getCurrentDirectory(self: *Host) []const u8 {
        return self.inner.getCurrentDirectory();
    }

    // GetSourceFile: cache dts/json files, passthrough others.
    // TODO(phase2.7): wire parseCache.loadOrStore for dts/json files.
};
