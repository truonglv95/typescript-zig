const std = @import("std");

//! Build orchestrator — coordinates `tsc --build` across multiple projects.
//!
//! Port of `internal/execute/build/orchestrator.go` (713 LOC).
//!
//! The orchestrator:
//! 1. Creates `BuildTask`s for each project reference
//! 2. Detects circular references
//! 3. Builds a topological order
//! 4. Executes tasks in parallel (respecting upstream dependencies)
//! 5. Collects results, errors, and statistics
//! 6. In watch mode, manages file watches and rebuilds on change

const buildtask = @import("buildtask.zig");
const tsc_compile = @import("../tsc/compile.zig");
const tsc_statistics = @import("../tsc/statistics.zig");
const diagnostics = @import("../../diagnostics/diagnostics.zig");
const tspath = @import("../../tspath/tspath.zig");

/// Orchestrator options. Port of Go's `build.Options`.
pub const Options = struct {
    /// System interface (FS, writer, cwd, etc.)
    sys: *anyopaque, // *tsc.System
    /// Parsed build command line.
    command: *anyopaque, // *tsoptions.ParsedBuildCommandLine
    /// Testing callbacks (null in production).
    testing: tsc_compile.CommandLineTesting = null,
};

/// Result of an orchestration cycle.
pub const OrchestratorResult = struct {
    result: tsc_compile.CommandLineResult = .{ .status = .Success },
    errors: std.ArrayListUnmanaged(diagnostics.Diagnostic) = .empty,
    statistics: tsc_statistics.Statistics = .{},
    files_to_delete: std.ArrayListUnmanaged([]const u8) = .empty,
};

/// The build orchestrator. Port of Go's `Orchestrator`.
pub const Orchestrator = struct {
    opts: Options,
    allocator: std.mem.Allocator,

    /// Build tasks keyed by path.
    tasks: std.StringHashMapUnmanaged(*buildtask.BuildTask) = .empty,
    /// Topological build order (config paths).
    order: std.ArrayListUnmanaged([]const u8) = .empty,
    /// Errors collected during task creation.
    errors: std.ArrayListUnmanaged(diagnostics.Diagnostic) = .empty,

    mu: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator, opts: Options) Orchestrator {
        return .{
            .opts = opts,
            .allocator = allocator,
            .mu = .{},
        };
    }

    pub fn deinit(self: *Orchestrator) void {
        var iter = self.tasks.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.*.deinit();
        }
        self.tasks.deinit(self.allocator);
        self.order.deinit(self.allocator);
        self.errors.deinit(self.allocator);
    }

    /// Returns the build order (list of config paths).
    pub fn getOrder(self: *const Orchestrator) []const []const u8 {
        return self.order.items;
    }

    /// Returns the upstream config paths for a given config.
    pub fn upstream(self: *Orchestrator, config_name: []const u8) []const []const u8 {
        const task = self.tasks.get(config_name) orelse return &.{};
        // Map upstream tasks to their config names.
        var result = std.ArrayListUnmanaged([]const u8).empty;
        for (task.upstream.items) |up| {
            result.append(self.allocator, up.task.config) catch break;
        }
        return result.toOwnedSlice(self.allocator) catch &.{};
    }

    /// Returns the downstream config paths for a given config.
    pub fn downstream(self: *Orchestrator, config_name: []const u8) []const []const u8 {
        const task = self.tasks.get(config_name) orelse return &.{};
        var result = std.ArrayListUnmanaged([]const u8).empty;
        for (task.downstream.items) |ds| {
            result.append(self.allocator, ds.config) catch break;
        }
        return result.toOwnedSlice(self.allocator) catch &.{};
    }

    /// Creates build tasks for the given config files.
    /// Port of Go's `createBuildTasks`.
    pub fn createBuildTasks(self: *Orchestrator, configs: []const []const u8) !void {
        for (configs) |config| {
            const path = config; // Simplified: would use tspath.ToPath
            if (self.tasks.contains(path)) continue;
            const task = buildtask.BuildTask.init(self.allocator, config);
            task.pending.store(true, .seq_cst);
            task.is_initial_cycle = true;
            _ = self.tasks.put(self.allocator, path, task) catch {};
            // TODO(phase2.7): resolve project references and recurse.
        }
    }

    /// Sets up the build task graph (upstream/downstream links) and
    /// detects circular references.
    /// Port of Go's `setupBuildTask`.
    pub fn setupBuildTaskGraph(self: *Orchestrator) !void {
        var completed = std.StringHashMapUnmanaged(void).empty;
        defer completed.deinit(self.allocator);
        var analyzing = std.StringHashMapUnmanaged(void).empty;
        defer analyzing.deinit(self.allocator);

        var iter = self.tasks.keyIterator();
        while (iter.next()) |path| {
            try self.setupTask(path.*, null, false, &completed, &analyzing);
        }
    }

    fn setupTask(
        self: *Orchestrator,
        config_name: []const u8,
        downstream_task: ?*buildtask.BuildTask,
        in_circular_context: bool,
        completed: *std.StringHashMapUnmanaged(void),
        analyzing: *std.StringHashMapUnmanaged(void),
    ) !void {
        if (completed.contains(config_name)) {
            // Already processed — just link downstream.
            if (downstream_task) |ds| {
                const task = self.tasks.get(config_name) orelse return;
                _ = task.downstream.append(self.allocator, ds) catch {};
            }
            return;
        }

        if (analyzing.contains(config_name)) {
            // Circular reference detected.
            if (!in_circular_context) {
                self.errors.append(self.allocator, .{
                    .message = &@import("../../diagnostics/diagnostics_generated.zig").Project_references_may_not_form_a_circular_graph_Cycle_detected_Colon_0,
                    .nodeIndex = 0,
                    .args = &.{config_name},
                }) catch {};
            }
            return;
        }

        _ = analyzing.put(self.allocator, config_name, {}) catch {};

        const task = self.tasks.get(config_name) orelse {
            _ = analyzing.remove(config_name);
            return;
        };

        // TODO(phase2.7): resolve upstream references and recurse.
        // For now, just add to the build order.

        _ = analyzing.remove(config_name);
        _ = completed.put(self.allocator, config_name, {}) catch {};

        _ = self.order.append(self.allocator, config_name) catch {};

        if (downstream_task) |ds| {
            _ = task.downstream.append(self.allocator, ds) catch {};
        }
    }

    /// Builds all projects in topological order.
    /// Port of Go's `buildAll`.
    pub fn buildAll(self: *Orchestrator) OrchestratorResult {
        var result = OrchestratorResult{};
        // Execute tasks in order.
        for (self.order.items) |config| {
            const task = self.tasks.get(config) orelse continue;
            task.buildProject();
            // Collect errors.
            self.mu.lock();
            for (task.errors.items) |err| {
                result.errors.append(self.allocator, err) catch break;
            }
            self.mu.unlock();
            if (task.result) |tr| {
                if (@intFromEnum(tr.exit_status) > @intFromEnum(result.result.status)) {
                    result.result.status = tr.exit_status;
                }
            }
        }
        return result;
    }

    /// DoCycle — called in watch mode to re-check and rebuild.
    /// Port of Go's `DoCycle`.
    pub fn doCycle(self: *Orchestrator) void {
        // In watch mode:
        // 1. Drain file change events from WatchManager
        // 2. Mark affected tasks as dirty
        // 3. Rebuild dirty tasks and their downstream
        // TODO(phase2.9): wire WatchManager integration.
        _ = self.buildAll();
    }
};
