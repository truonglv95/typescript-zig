const std = @import("std");
const session = @import("session.zig");
const project = @import("project.zig");
const filechange = @import("filechange.zig");

pub const APIOpenProjectResult = struct {
    project: *project.Project,
    snapshot: *session.Snapshot,
};

pub fn apiOpenProject(
    s: *session.Session,
    configFileName: []const u8,
    apiFileChanges: filechange.FileChangeSummary,
) !APIOpenProjectResult {
    s.snapshotUpdateMu.lock();
    defer s.snapshotUpdateMu.unlock();
    s.cancelScheduledSnapshotUpdate();

    var changes_and_overlays = try s.flushChanges();
    var fileChanges = changes_and_overlays[0];
    const overlays = changes_and_overlays[1];

    try fileChanges.merge(&apiFileChanges);

    const newSnapshot = try s.updateSnapshotRef(overlays, .{
        .fileChanges = fileChanges,
    });

    // In a full implementation, we'd fetch the configured project from the newSnapshot's ProjectCollection
    // Since we are mocking snapshot here, we'll return a mock project.
    var p = try project.Project.newProject(s.allocator, configFileName, .Configured, configFileName, null);

    return APIOpenProjectResult{
        .project = p,
        .snapshot = newSnapshot,
    };
}

pub fn apiUpdateWithFileChanges(
    s: *session.Session,
    apiFileChanges: filechange.FileChangeSummary,
) !*session.Snapshot {
    s.snapshotUpdateMu.lock();
    defer s.snapshotUpdateMu.unlock();
    s.cancelScheduledSnapshotUpdate();

    var changes_and_overlays = try s.flushChanges();
    var fileChanges = changes_and_overlays[0];
    const overlays = changes_and_overlays[1];

    try fileChanges.merge(&apiFileChanges);

    return try s.updateSnapshotRef(overlays, .{
        .fileChanges = fileChanges,
    });
}
