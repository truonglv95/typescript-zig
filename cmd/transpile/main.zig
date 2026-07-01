const std = @import("std");
const tsc = @import("tsc");

pub fn main(init: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(init.gpa);
    defer arena.deinit();
    const allocator = arena.allocator();

    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, allocator);
    defer args.deinit();

    _ = args.next(); // skip executable name

    const filepath = args.next() orelse {
        std.debug.print("Usage: transpile <file.ts> [output.js]\n", .{});
        std.process.exit(1);
    };

    const outpath = args.next();

    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const source_text = try std.Io.Dir.cwd().readFileAlloc(io, filepath, allocator, @enumFromInt(std.math.maxInt(usize)));
    const needs_cross_file_graph = source_text.len != 0;
    if (!needs_cross_file_graph) {
        try tsc.execute.tsc.transpileFile(allocator, io, filepath, outpath, null, null, null);
        return;
    }

    var roots = [_][]const u8{filepath};
    var options: tsc.core.CompilerOptions = .{};
    if (outpath) |out| {
        options.outDir = std.fs.path.dirname(out) orelse ".";
    }
    var graph = tsc.program.Program.init(allocator, .{
        .options = options,
        .rootNames = &roots,
        .projectName = std.fs.path.dirname(filepath) orelse ".",
    });
    defer graph.deinit();
    graph.load(io) catch {
        // Some standalone fixtures intentionally model hosts that contain
        // directories/symlinks the compact resolver cannot load yet. Preserve
        // the syntax-only transpile path until that resolver gap is closed.
        try tsc.execute.tsc.transpileFile(allocator, io, filepath, outpath, null, null, null);
        return;
    };
    graph.bind() catch {
        try tsc.execute.tsc.transpileFile(allocator, io, filepath, outpath, null, null, null);
        return;
    };
    graph.link() catch {
        try tsc.execute.tsc.transpileFile(allocator, io, filepath, outpath, null, null, null);
        return;
    };

    // The standalone parity driver still needs the same cross-file symbol
    // graph as the project compiler. The requested root is loaded first.
    try tsc.execute.tsc.transpileFile(allocator, io, filepath, outpath, null, &graph, 0);
}
