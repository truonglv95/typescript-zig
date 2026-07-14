const std = @import("std");

//! Build compiler host — wraps the build host as a CompilerHost.
//!
//! Port of `internal/execute/build/compilerHost.go` (41 LOC).
//!
//! This is a thin adapter that delegates to the build host, adding
//! trace output support.

const host_mod = @import("host.zig");
const compiler = @import("../../compiler/compiler.zig");
const vfs = @import("../../vfs/vfs.zig");
const diagnostics = @import("../../diagnostics/diagnostics.zig");

/// Build compiler host — delegates to the build host with trace support.
/// Port of Go's `build.compilerHost`.
pub const CompilerHost = struct {
    host: *host_mod.Host,
    trace_fn: ?*const fn (msg: *const diagnostics.Message, args: []const []const u8) void = null,

    pub fn init(host: *host_mod.Host, trace_fn: ?*const fn (msg: *const diagnostics.Message, args: []const []const u8) void) CompilerHost {
        return .{ .host = host, .trace_fn = trace_fn };
    }

    pub fn fs(self: *CompilerHost) *vfs.FS {
        return self.host.fs();
    }

    pub fn defaultLibraryPath(self: *CompilerHost) []const u8 {
        return self.host.defaultLibraryPath();
    }

    pub fn getCurrentDirectory(self: *CompilerHost) []const u8 {
        return self.host.getCurrentDirectory();
    }

    pub fn trace(self: *CompilerHost, msg: *const diagnostics.Message, args: []const []const u8) void {
        if (self.trace_fn) |f| f(msg, args);
    }

    // GetSourceFile and GetResolvedProjectReference delegate to host.
    // TODO(phase2.7): wire through host methods.
};
