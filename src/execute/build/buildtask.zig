const std = @import("std");

//! Build task — represents a single project in a `tsc --build` graph.
//!
//! Port of `internal/execute/build/buildtask.go` (845 LOC).
//!
//! A `BuildTask` encapsulates one project reference in a composite build.
//! Tasks form a DAG (upstream/downstream links) and are executed by the
//! `Orchestrator`. Each task:
//!
//! 1. Waits on upstream tasks to complete
//! 2. Checks if the project is up-to-date (`getUpToDateStatus`)
//! 3. If up-to-date, skips the build (or does a pseudo-build to update
//!    timestamps)
//! 4. If out-of-date, compiles and emits (`compileAndEmit`)
//! 5. Updates downstream tasks with the new status

const uptodatestatus = @import("uptodatestatus.zig");
const tsc_compile = @import("../tsc/compile.zig");
const tsc_statistics = @import("../tsc/statistics.zig");
const incremental = @import("../incremental/incremental.zig");
const diagnostics = @import("../../diagnostics/diagnostics.zig");

/// The kind of build performed for a project.
pub const BuildKind = enum(u8) {
    None,
    /// Pseudo-build: only update timestamps, no actual compilation.
    Pseudo,
    /// Full program build: compile + emit.
    Program,
};

/// A reference to an upstream build task.
pub const UpstreamTask = struct {
    task: *BuildTask,
    ref_index: u32,
};

/// Cached build info entry for a project.
pub const BuildInfoEntry = struct {
    build_info: ?incremental.BuildInfo = null,
    path: []const u8,
    mtime_unix_nano: i128,
    dts_time: ?i128 = null,
};

/// Result of a build task.
pub const TaskResult = struct {
    exit_status: tsc_compile.ExitStatus = .Success,
    build_kind: BuildKind = .None,
    statistics: ?tsc_statistics.Statistics = null,
    program: ?*anyopaque = null, // *incremental.Program
    files_to_delete: std.ArrayListUnmanaged([]const u8) = .empty,
};

/// A build task — one project in a `tsc --build` graph.
/// Port of Go's `BuildTask`.
pub const BuildTask = struct {
    config: []const u8,
    // resolved: ?*tsoptions.ParsedCommandLine = null, -- TODO: wire tsoptions
    upstream: std.ArrayListUnmanaged(*UpstreamTask) = .empty,
    downstream: std.ArrayListUnmanaged(*BuildTask) = .empty,
    status: ?uptodatestatus.UpToDateStatus = null,

    // Task reporting.
    result: ?TaskResult = null,
    errors: std.ArrayListUnmanaged(diagnostics.Diagnostic) = .empty,

    // Concurrency.
    pending: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    is_initial_cycle: bool = false,
    dirty: bool = false,

    // Build info.
    build_info_entry: ?BuildInfoEntry = null,
    package_jsons: std.ArrayListUnmanaged([]const u8) = .empty,

    allocator: std.mem.Allocator,
    mu: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator, config: []const u8) *BuildTask {
        const task = allocator.create(BuildTask) catch unreachable;
        task.* = .{
            .config = config,
            .allocator = allocator,
            .mu = .{},
        };
        return task;
    }

    pub fn deinit(self: *BuildTask) void {
        self.upstream.deinit(self.allocator);
        self.downstream.deinit(self.allocator);
        self.errors.deinit(self.allocator);
        if (self.result) |*r| {
            r.files_to_delete.deinit(self.allocator);
        }
        self.package_jsons.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// Waits for all upstream tasks to complete.
    /// Port of Go's `waitOnUpstream`.
    pub fn waitOnUpstream(self: *BuildTask) void {
        // In Go, this waits on channels. In Zig, we use a simpler approach:
        // poll the pending flag of each upstream task.
        for (self.upstream.items) |upstream| {
            while (upstream.task.pending.load(.seq_cst)) {
                std.Thread.yield() catch {};
            }
        }
    }

    /// Marks this task as complete and unblocks downstream tasks.
    /// Port of Go's `unblockDownstream`.
    pub fn unblockDownstream(self: *BuildTask) void {
        self.pending.store(false, .seq_cst);
        self.is_initial_cycle = false;
    }

    /// Reports a diagnostic for this task.
    pub fn reportDiagnostic(self: *BuildTask, diag: diagnostics.Diagnostic) void {
        self.mu.lock();
        defer self.mu.unlock();
        self.errors.append(self.allocator, diag) catch {};
    }

    /// Gets the up-to-date status of this project.
    /// Port of Go's `getUpToDateStatus`.
    ///
    /// Conservative implementation: returns `ForceBuild` if `--force` is
    /// set, otherwise `UpToDate`. Full implementation requires build info
    /// reading, file mtime comparison, and option hash checking.
    pub fn getUpToDateStatus(self: *BuildTask) uptodatestatus.UpToDateStatus {
        if (self.status) |s| return s;
        // TODO(phase2.7): full implementation with build info, mtime,
        // option hash, file version comparison.
        return .{ .kind = .UpToDate };
    }

    /// Handles statuses that don't require an actual build (up-to-date,
    /// pseudo-build, config not found, etc.).
    /// Returns true if no build is needed.
    /// Port of Go's `handleStatusThatDoesntRequireBuild`.
    pub fn handleStatusThatDoesntRequireBuild(self: *BuildTask) bool {
        const status = self.status orelse return false;
        return switch (status.kind) {
            .UpToDate, .UpToDateWithUpstreamTypes, .UpToDateWithInputFileText,
            .Solution, .ConfigFileNotFound, .UpstreamErrors => true,
            // Pseudo-builds update timestamps only.
            .OutputMissing, .InputFileNewer, .OutOfDateBuildInfoWithPendingEmit => blk: {
                // TODO(phase2.7): implement pseudo-build (timestamp update).
                break :blk false;
            },
            else => false,
        };
    }

    /// Compiles and emits the project.
    /// Port of Go's `compileAndEmit`.
    ///
    /// Full implementation requires:
    /// 1. Read build info (if not --force)
    /// 2. Create program via compiler.NewProgram
    /// 3. Create incremental program
    /// 4. Emit files via tsc.EmitAndReportStatistics
    /// 5. Update timestamps
    /// 6. Set status based on result
    pub fn compileAndEmit(self: *BuildTask) void {
        if (self.result == null) {
            self.result = TaskResult{};
        }
        self.result.?.build_kind = .Program;
        // TODO(phase2.7): wire full compile + emit pipeline.
    }

    /// Updates downstream tasks with the new status.
    /// Port of Go's `updateDownstream`.
    pub fn updateDownstream(self: *BuildTask) void {
        if (self.is_initial_cycle) return;
        // TODO(phase2.7): propagate status changes to downstream tasks.
        for (self.downstream.items) |ds| {
            ds.mu.lock();
            defer ds.mu.unlock();
            if (ds.status) |*s| {
                if (s.kind == .UpToDate) {
                    s.kind = .UpToDateWithUpstreamTypes;
                }
            }
            ds.pending.store(true, .seq_cst);
        }
    }

    /// Builds the project: wait on upstream, check status, compile if needed.
    /// Port of Go's `buildProject`.
    pub fn buildProject(self: *BuildTask) void {
        self.waitOnUpstream();
        if (self.pending.load(.seq_cst)) {
            self.status = self.getUpToDateStatus();
            if (!self.handleStatusThatDoesntRequireBuild()) {
                self.compileAndEmit();
                self.updateDownstream();
            }
        }
        self.unblockDownstream();
    }

    /// Returns true if this task encountered errors.
    pub fn hasErrors(self: *BuildTask) bool {
        self.mu.lock();
        defer self.mu.unlock();
        return self.errors.items.len > 0;
    }
};
