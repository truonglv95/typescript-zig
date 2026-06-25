const std = @import("std");

var recorded_baselines: ?std.StringHashMap(void) = null;
var tracking_initialized: bool = false;
var tracking_dir_val: ?[]const u8 = null;
var tracking_dir_initialized: bool = false;
var tracking_allocator: ?std.mem.Allocator = null;

fn trackingDir(allocator: std.mem.Allocator) ?[]const u8 {
    if (tracking_dir_initialized) return tracking_dir_val;
    tracking_dir_initialized = true;
    if (std.posix.getenv("TSGO_BASELINE_TRACKING_DIR")) |v| {
        tracking_dir_val = allocator.dupe(u8, v) catch null;
    }
    return tracking_dir_val;
}

pub fn track(allocator: std.mem.Allocator) !void {
    tracking_initialized = true;
    tracking_allocator = allocator;
    const tdir = trackingDir(allocator);
    if (tdir == null) {
        return;
    }
    if (recorded_baselines == null) {
        recorded_baselines = std.StringHashMap(void).init(allocator);
    }
}

pub fn recordBaseline(relative_path: []const u8) !void {
    if (tracking_dir_val != null) {
        if (!tracking_initialized) {
            std.debug.panic("baseline: package uses baselines but testmain did not call track().", .{});
        }
        if (recorded_baselines) |*set| {
            try set.put(try tracking_allocator.?.dupe(u8, relative_path), {});
        }
    }
}

pub fn writeRecordedBaselines(allocator: std.mem.Allocator, tracking_path: []const u8) !void {
    if (recorded_baselines == null or recorded_baselines.?.count() == 0) {
        return;
    }

    doWriteRecordedBaselines(allocator, tracking_path) catch |err| {
        std.debug.print("baseline: failed to write tracking file {s}: {any}\n", .{ tracking_path, err });
        std.posix.exit(1);
    };
}

fn doWriteRecordedBaselines(allocator: std.mem.Allocator, tracking_path: []const u8) !void {
    _ = allocator;
    const file = try std.fs.cwd().createFile(tracking_path, .{});
    defer file.close();

    var buf_writer = std.io.bufferedWriter(file.writer());
    const writer = buf_writer.writer();

    var it = recorded_baselines.?.keyIterator();
    while (it.next()) |baseline| {
        try writer.print("{s}\n", .{baseline.*});
    }
    try buf_writer.flush();
}
