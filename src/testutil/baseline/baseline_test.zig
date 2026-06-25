const std = @import("std");
const baseline = @import("baseline.zig");

test "SubmoduleAcceptedFilesExist" {
    const allocator = std.testing.allocator;
    const accepted = try baseline.submoduleAcceptedFileNames(allocator);
    var it = accepted.keyIterator();
    while (it.next()) |name| {
        const ref_root = try baseline.referenceRoot(allocator);
        const path = try std.fs.path.join(allocator, &.{ ref_root, "submoduleAccepted", name.* });
        defer allocator.free(path);
        
        if (std.Io.Dir.cwd().access(std.testing.io, path, .{})) |_| {} else |_| {
            std.debug.panic("submoduleAccepted.txt references \"{s}\", but the baseline file does not exist", .{ name.* });
        }
    }
}

test "SubmoduleTriagedFilesExist" {
    const allocator = std.testing.allocator;
    const triaged = try baseline.submoduleTriagedFileNames(allocator);
    var it = triaged.keyIterator();
    while (it.next()) |name| {
        const ref_root = try baseline.referenceRoot(allocator);
        const path = try std.fs.path.join(allocator, &.{ ref_root, "submoduleTriaged", name.* });
        defer allocator.free(path);
        
        if (std.Io.Dir.cwd().access(std.testing.io, path, .{})) |_| {} else |_| {
            std.debug.panic("submoduleTriaged.txt references \"{s}\", but the baseline file does not exist", .{ name.* });
        }
    }
}
