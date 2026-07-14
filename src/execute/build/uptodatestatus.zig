const std = @import("std");

//! Up-to-date status tracking for `tsc --build`.
//!
//! Port of `internal/execute/build/uptodatestatus.go` (133 LOC).
//!
//! Tracks why a project is or isn't up to date during a build.
//! Used to determine whether a project needs to be rebuilt.

/// The kind of up-to-date status. Port of Go's `upToDateStatusType`.
pub const UpToDateStatusType = enum(u16) {
    // Errors:
    /// Config file was not found.
    ConfigFileNotFound,
    /// Found errors during build.
    BuildErrors,
    /// Did not build because upstream project has errors.
    UpstreamErrors,

    // All good, no work to do:
    /// Project is up to date.
    UpToDate,

    // Pseudo-builds (touch timestamps, no actual build):
    /// Upstream inputs are newer but outputs are newer than previous identical outputs.
    UpToDateWithUpstreamTypes,
    /// Input file changed on disk but its text didn't — just update timestamps.
    UpToDateWithInputFileText,

    // Needs build:
    /// Input file is missing.
    InputFileMissing,
    /// Output file is missing.
    OutputMissing,
    /// Input file is newer than output file.
    InputFileNewer,
    /// Build info is out of date — need to emit some files.
    OutOfDateBuildInfoWithPendingEmit,
    /// Build info indicates project has errors that need reporting.
    OutOfDateBuildInfoWithErrors,
    /// Build info options changed — there is work to do.
    OutOfDateOptions,
    /// File was root when built but not any more.
    OutOfDateRoots,
    /// BuildInfo version mismatch with current TS version.
    TsVersionOutputOfDate,
    /// Build because `--force` was specified.
    ForceBuild,

    // Solution file:
    /// This is a solution-style tsconfig (references multiple projects).
    Solution,
};

/// A file path and its modification time.
pub const FileAndTime = struct {
    file: []const u8,
    time_unix_nano: i128,
};

/// An input/output file pair with their times and build info path.
pub const InputOutputFileAndTime = struct {
    input: FileAndTime,
    output: FileAndTime,
    build_info: []const u8,
};

/// Upstream error info.
pub const UpstreamErrors = struct {
    ref: []const u8,
    ref_has_upstream_errors: bool,
};

/// The up-to-date status of a project. Port of Go's `upToDateStatus`.
pub const UpToDateStatus = struct {
    kind: UpToDateStatusType,
    /// Optional data associated with the status (e.g. file paths, error info).
    /// Stored as an opaque union for simplicity.
    data: ?*anyopaque = null,

    /// Returns true if this status represents an error condition.
    pub fn isError(self: UpToDateStatus) bool {
        return switch (self.kind) {
            .ConfigFileNotFound, .BuildErrors, .UpstreamErrors, .InputFileMissing => true,
            else => false,
        };
    }

    /// Returns true if the project is up to date (no build needed).
    pub fn isUpToDate(self: UpToDateStatus) bool {
        return switch (self.kind) {
            .UpToDate, .UpToDateWithUpstreamTypes, .UpToDateWithInputFileText => true,
            else => false,
        };
    }
};
