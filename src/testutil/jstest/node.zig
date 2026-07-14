const std = @import("std");
const json = @import("../../json/json.zig");
const repo = @import("../../repo/paths.zig");
const tspath = @import("../../tspath/tspath.zig");

const loader_script =
    \\import script from "./script.mjs";
    \\process.stdout.write(JSON.stringify(await script(...process.argv.slice(2))));
;

fn getNodeExe(allocator: std.mem.Allocator) ![]const u8 {
    _ = allocator;
    return "node";
}

// EvalNodeScript imports a Node.js script that default-exports a single function,
// calls it with the provided arguments, and unmarshals the JSON-stringified
// awaited return value into T.
pub fn evalNodeScript(comptime T: type, allocator: std.mem.Allocator, script: []const u8, dir: []const u8, args: []const []const u8) !T {
    return evalNodeScriptInternal(T, allocator, script, loader_script, dir, args);
}

// EvalNodeScriptWithTS is like EvalNodeScript, but provides the TypeScript
// library to the script as the first argument.
pub fn evalNodeScriptWithTS(comptime T: type, allocator: std.mem.Allocator, script: []const u8, dir: []const u8, args: []const []const u8) !T {
    var actual_dir = dir;
    if (actual_dir.len == 0) {
        // Not handled out of the box in this port, usually caller provides dir
        return error.DirRequired;
    }

    const root = try repo.rootPath(allocator);
    const ts_lib_path = try std.fs.path.join(allocator, &[_][]const u8{ root, "node_modules", "typescript", "lib", "typescript.js" });
    defer allocator.free(ts_lib_path);

    const ts_src = try tspath.normalizePath(allocator, ts_lib_path);
    defer allocator.free(ts_src);

    var ts_src_url = std.ArrayList(u8).init(allocator);
    defer ts_src_url.deinit();

    if (ts_src.len > 0 and ts_src[0] == '/') {
        try ts_src_url.appendSlice("file://");
        try ts_src_url.appendSlice(ts_src);
    } else {
        try ts_src_url.appendSlice("file:///");
        try ts_src_url.appendSlice(ts_src);
    }

    const ts_loader_script = try std.fmt.allocPrint(allocator, 
        \\import script from "./script.mjs";
        \\import * as ts from "{s}";
        \\process.stdout.write(JSON.stringify(await script(ts, ...process.argv.slice(2))));
    , .{ts_src_url.items});
    defer allocator.free(ts_loader_script);

    return evalNodeScriptInternal(T, allocator, script, ts_loader_script, actual_dir, args);
}

pub fn skipIfNoNodeJS(allocator: std.mem.Allocator) !bool {
    const exe = try getNodeExe(allocator);
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ exe, "-v" },
    }) catch |err| {
        if (err == error.FileNotFound) {
            return true;
        }
        return err;
    };
    allocator.free(result.stdout);
    allocator.free(result.stderr);
    return false;
}

fn evalNodeScriptInternal(comptime T: type, allocator: std.mem.Allocator, script: []const u8, loader: []const u8, dir: []const u8, args: []const []const u8) !T {
    const exe = try getNodeExe(allocator);

    const script_path = try std.fs.path.join(allocator, &[_][]const u8{ dir, "script.mjs" });
    defer allocator.free(script_path);

    var file1 = try std.fs.cwd().createFile(script_path, .{});
    try file1.writeAll(script);
    file1.close();

    const loader_path = try std.fs.path.join(allocator, &[_][]const u8{ dir, "loader.mjs" });
    defer allocator.free(loader_path);

    var file2 = try std.fs.cwd().createFile(loader_path, .{});
    try file2.writeAll(loader);
    file2.close();

    var exec_args = std.ArrayList([]const u8).init(allocator);
    defer exec_args.deinit();
    try exec_args.append(exe);
    try exec_args.append(loader_path);
    for (args) |arg| {
        try exec_args.append(arg);
    }

    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = exec_args.items,
        .cwd = dir,
    });
    defer {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
    }

    if (result.term != .Exited or result.term.Exited != 0) {
        std.debug.print("failed to run node: {s}\n", .{result.stderr});
        return error.NodeExecutionFailed;
    }

    var result_val: T = undefined;
    try json.unmarshal(allocator, result.stdout, &result_val, .{});
    return result_val;
}
