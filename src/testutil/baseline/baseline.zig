const std = @import("std");
const repo = @import("../../repo/paths.zig");
const testmain = @import("testmain.zig");

pub const Options = struct {
    subfolder: []const u8,
    is_submodule: bool = false,
    is_submodule_accepted: bool = false,
    is_submodule_triaged: bool = false,
    diff_fixup_old: ?*const fn (std.mem.Allocator, []const u8) []const u8 = null,
    diff_fixup_new: ?*const fn (std.mem.Allocator, []const u8) []const u8 = null,
    skip_diff_with_old: bool = false,
};

pub const no_content = "<no content>";

pub fn run(allocator: std.mem.Allocator, file_name: []const u8, actual: []const u8, opts: Options) !void {
    const orig_subfolder = opts.subfolder;

    {
        var subfolder = opts.subfolder;
        if (opts.is_submodule) {
            subfolder = try std.fs.path.join(allocator, &.{ "submodule", subfolder });
        }

        const l_root = try localRoot(allocator);
        const r_root = try referenceRoot(allocator);

        const local_path = try std.fs.path.join(allocator, &.{ l_root, subfolder, file_name });
        const reference_path = try std.fs.path.join(allocator, &.{ r_root, subfolder, file_name });

        const track_path = try std.fs.path.join(allocator, &.{ subfolder, file_name });
        try testmain.recordBaseline(track_path);

        try writeComparison(allocator, actual, local_path, reference_path, false);
    }

    if (!opts.is_submodule or opts.skip_diff_with_old) {
        return;
    }

    const sub_ref_root = try submoduleReferenceRoot(allocator);
    const submodule_reference = try std.fs.path.join(allocator, &.{ sub_ref_root, file_name });
    const submodule_expected = readFileOrNoContent(allocator, submodule_reference) catch no_content;

    const submodule_folder = "submodule";
    const submodule_accepted_folder = "submoduleAccepted";
    const submodule_triaged_folder = "submoduleTriaged";

    const diff_file_name = try std.fmt.allocPrint(allocator, "{s}.diff", .{file_name});
    const diff_key = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ orig_subfolder, diff_file_name });

    const accepted_set = try submoduleAcceptedFileNames(allocator);
    const is_submodule_accepted = opts.is_submodule_accepted or accepted_set.contains(diff_key);

    const triaged_set = try submoduleTriagedFileNames(allocator);
    const is_submodule_triaged = opts.is_submodule_triaged or triaged_set.contains(diff_key);

    if (is_submodule_accepted and is_submodule_triaged) {
        std.debug.panic("diff file {s}/{s} is in both submoduleAccepted and submoduleTriaged; it should only be in one", .{ orig_subfolder, diff_file_name });
    }

    var out_root: []const u8 = undefined;
    if (is_submodule_accepted) {
        out_root = submodule_accepted_folder;
    } else if (is_submodule_triaged) {
        out_root = submodule_triaged_folder;
    } else {
        out_root = submodule_folder;
    }

    const all_roots = [_][]const u8{ submodule_folder, submodule_accepted_folder, submodule_triaged_folder };

    const diff = try getBaselineDiff(allocator, actual, submodule_expected, file_name, opts.diff_fixup_old, opts.diff_fixup_new);

    for (all_roots) |root| {
        const l_root = try localRoot(allocator);
        const r_root = try referenceRoot(allocator);

        const local_path = try std.fs.path.join(allocator, &.{ l_root, root, orig_subfolder, diff_file_name });
        const reference_path = try std.fs.path.join(allocator, &.{ r_root, root, orig_subfolder, diff_file_name });

        const track_path = try std.fs.path.join(allocator, &.{ root, orig_subfolder, diff_file_name });
        try testmain.recordBaseline(track_path);

        if (std.mem.eql(u8, root, out_root)) {
            try writeComparison(allocator, diff, local_path, reference_path, false);
        } else {
            try writeComparison(allocator, no_content, local_path, reference_path, false);
        }
    }
}

var submodule_accepted_file_names_cache: ?std.StringHashMap(void) = null;
pub fn submoduleAcceptedFileNames(allocator: std.mem.Allocator) !*std.StringHashMap(void) {
    if (submodule_accepted_file_names_cache == null) {
        const test_data_path = try repo.testDataPath(allocator);
        const path = try std.fs.path.join(allocator, &.{ test_data_path, "submoduleAccepted.txt" });
        submodule_accepted_file_names_cache = try readFileNameSet(allocator, path);
    }
    return &submodule_accepted_file_names_cache.?;
}

var submodule_triaged_file_names_cache: ?std.StringHashMap(void) = null;
pub fn submoduleTriagedFileNames(allocator: std.mem.Allocator) !*std.StringHashMap(void) {
    if (submodule_triaged_file_names_cache == null) {
        const test_data_path = try repo.testDataPath(allocator);
        const path = try std.fs.path.join(allocator, &.{ test_data_path, "submoduleTriaged.txt" });
        submodule_triaged_file_names_cache = try readFileNameSet(allocator, path);
    }
    return &submodule_triaged_file_names_cache.?;
}

fn readFileNameSet(allocator: std.mem.Allocator, path: []const u8) !std.StringHashMap(void) {
    var set = std.StringHashMap(void).init(allocator);

    const content = std.Io.Dir.cwd().readFileAlloc(std.testing.io, path, allocator, .unlimited) catch |err| {
        std.debug.panic("failed to read file {s}: {any}", .{ path, err });
    };
    defer allocator.free(content);

    var it = std.mem.splitScalar(u8, content, '\n');
    while (it.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0 or trimmed[0] == '#') {
            continue;
        }
        try set.put(try allocator.dupe(u8, trimmed), {});
    }

    return set;
}

fn readFileOrNoContent(allocator: std.mem.Allocator, file_name: []const u8) ![]const u8 {
    const file = std.fs.cwd().openFile(file_name, .{}) catch return no_content;
    defer file.close();
    return try file.readToEndAlloc(allocator, std.math.maxInt(usize));
}

pub fn diffText(allocator: std.mem.Allocator, old_name: []const u8, new_name: []const u8, expected: []const u8, actual: []const u8) ![]const u8 {
    if (std.mem.eql(u8, expected, actual)) {
        return try allocator.dupe(u8, "");
    }
    return try std.fmt.allocPrint(allocator, "--- {s}\n+++ {s}\n@@ -1 +1 @@\n- {s}\n+ {s}\n", .{ old_name, new_name, expected, actual });
}

pub fn getBaselineDiff(allocator: std.mem.Allocator, actual_in: []const u8, expected_in: []const u8, file_name: []const u8, fixup_old: ?*const fn (std.mem.Allocator, []const u8) []const u8, fixup_new: ?*const fn (std.mem.Allocator, []const u8) []const u8) ![]const u8 {
    var expected = expected_in;
    var actual = actual_in;

    if (fixup_old) |f| {
        expected = f(allocator, expected);
    }
    if (fixup_new) |f| {
        actual = f(allocator, actual);
    }

    if (std.mem.eql(u8, actual, expected)) {
        return no_content;
    }

    const old_name = try std.fmt.allocPrint(allocator, "old.{s}", .{file_name});
    const new_name = try std.fmt.allocPrint(allocator, "new.{s}", .{file_name});

    const s = try diffText(allocator, old_name, new_name, expected, actual);

    if (std.mem.indexOf(u8, s, "@@") == null) {
        return no_content;
    }

    return s;
}

pub fn runAgainstSubmodule(allocator: std.mem.Allocator, file_name: []const u8, actual: []const u8, opts: Options) !void {
    const track_path = try std.fs.path.join(allocator, &.{ opts.subfolder, file_name });
    try testmain.recordBaseline(track_path);

    const l_root = try localRoot(allocator);
    const sub_ref_root = try submoduleReferenceRoot(allocator);

    const local_path = try std.fs.path.join(allocator, &.{ l_root, opts.subfolder, file_name });
    const reference_path = try std.fs.path.join(allocator, &.{ sub_ref_root, opts.subfolder, file_name });

    try writeComparison(allocator, actual, local_path, reference_path, true);
}

fn writeComparison(allocator: std.mem.Allocator, actual_content: []const u8, local_path: []const u8, reference_path: []const u8, comparing_against_submodule: bool) !void {
    if (actual_content.len == 0) {
        std.debug.panic("the generated content was \"\". Return 'baseline.no_content' if no baselining is required.", .{});
    }

    if (std.fs.path.dirname(local_path)) |dir| {
        std.fs.cwd().makePath(dir) catch |err| {
            std.debug.panic("failed to create directories for the local baseline file {s}: {any}", .{ local_path, err });
        };
    }

    std.fs.cwd().deleteFile(local_path) catch {};

    var expected: []const u8 = no_content;
    var found_expected = false;

    if (std.fs.cwd().openFile(reference_path, .{})) |file| {
        expected = file.readToEndAlloc(allocator, std.math.maxInt(usize)) catch no_content;
        file.close();
        found_expected = true;
    } else |_| {}

    if (!std.mem.eql(u8, expected, actual_content) or (std.mem.eql(u8, actual_content, no_content) and found_expected)) {
        if (std.mem.eql(u8, actual_content, no_content)) {
            const del_path = try std.fmt.allocPrint(allocator, "{s}.delete", .{local_path});
            const f = try std.fs.cwd().createFile(del_path, .{});
            f.close();
        } else {
            const f = try std.fs.cwd().createFile(local_path, .{});
            try f.writeAll(actual_content);
            f.close();
        }

        if (std.fs.cwd().access(reference_path, .{})) |_| {} else |_| {
            if (comparing_against_submodule) {
                std.debug.panic("the baseline file {s} does not exist in the TypeScript submodule", .{reference_path});
            } else {
                std.debug.panic("new baseline created at {s}.", .{local_path});
            }
            return;
        }

        if (comparing_against_submodule) {
            std.debug.panic("the baseline file {s} does not match the reference in the TypeScript submodule", .{reference_path});
        } else {
            std.debug.panic("the baseline file {s} has changed. (Run `hereby baseline-accept` if the new baseline is correct.)", .{reference_path});
        }
    }
}

pub fn localRoot(allocator: std.mem.Allocator) ![]const u8 {
    return try std.fs.path.join(allocator, &.{ try repo.testDataPath(allocator), "baselines", "local" });
}

pub fn referenceRoot(allocator: std.mem.Allocator) ![]const u8 {
    return try std.fs.path.join(allocator, &.{ try repo.testDataPath(allocator), "baselines", "reference" });
}

pub fn submoduleReferenceRoot(allocator: std.mem.Allocator) ![]const u8 {
    return try std.fs.path.join(allocator, &.{ try repo.typeScriptSubmodulePath(allocator), "tests", "baselines", "reference" });
}
