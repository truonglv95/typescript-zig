const std = @import("std");
const system = @import("execute/system.zig");

/// OS-backed `System` implementation used by the standalone `tsc` CLI binary.
///
/// `OsSystem` owns:
///   * the working directory (read from `std.process.getCwd` at init time)
///   * the process start time (used by `sinceStart`)
///   * the default library path (overridable via `TYPESCRIPT_ZIG_LIB_PATH`)
///
/// All string memory returned from `sys()` callbacks is owned by `OsSystem`
/// and lives until `deinit` is called.
pub const OsSystem = struct {
    allocator: std.mem.Allocator,
    cwd: []const u8,
    default_lib_path: []const u8,
    start_ns: i128,
    is_tty: bool,
    term_width: usize,

    pub fn init(allocator: std.mem.Allocator) OsSystem {
        // Zig 0.16 removed std.process.getCwd. Use linux.getcwd syscall.
        var cwd_buf: [std.fs.max_path_bytes]u8 = undefined;
        const cwd = blk: {
            if (@hasDecl(std.os.linux, "getcwd")) {
                const rc = std.os.linux.getcwd(&cwd_buf, cwd_buf.len);
                const err = std.os.linux.errno(rc);
                if (err == .SUCCESS) break :blk std.mem.sliceTo(&cwd_buf, 0);
            }
            break :blk ".";
        };
        const cwd_dup = allocator.dupe(u8, cwd) catch ".";

        // Lib path: prefer $TYPESCRIPT_ZIG_LIB_PATH, otherwise empty.
        // Zig 0.16: environment access requires Io; fall back to null.
        const env_lib: ?[]const u8 = null;

        const is_tty = false; // Zig 0.16: std.fs.File API changed; skip TTY detection.

        return .{
            .allocator = allocator,
            .cwd = cwd_dup,
            .default_lib_path = if (env_lib) |p| p else "",
            .start_ns = blk: {
                // Zig 0.16 removed std.time.nanoTimestamp.
                var ts: std.os.linux.timespec = undefined;
                _ = std.os.linux.clock_gettime(.REALTIME, &ts);
                break :blk @as(i128, ts.sec) * std.time.ns_per_s + @as(i128, ts.nsec);
            },
            .is_tty = is_tty,
            .term_width = detectTerminalWidth(),
        };
    }

    pub fn deinit(self: *OsSystem) void {
        if (self.cwd.len > 0 and !std.mem.eql(u8, self.cwd, ".")) {
            self.allocator.free(self.cwd);
        }
        if (self.default_lib_path.len > 0) {
            self.allocator.free(self.default_lib_path);
        }
    }

    pub fn sys(self: *OsSystem) system.System {
        return .{
            .context = self,
            .writerFn = writerFn,
            .defaultLibraryPathFn = defaultLibraryPathFn,
            .getCurrentDirectoryFn = getCurrentDirectoryFn,
            .writeOutputIsTTYFn = writeOutputIsTTYFn,
            .getWidthOfTerminalFn = getWidthOfTerminalFn,
            .getEnvironmentVariableFn = getEnvironmentVariableFn,
            .nowFn = nowFn,
            .sinceStartFn = sinceStartFn,
        };
    }

    fn writerFn(ctx: *anyopaque) *anyopaque {
        // Returns a pointer to the stdout writer. The caller (System.writer)
        // casts this back as needed. We return the OsSystem itself as a stable
        // pointer; downstream code can reach stdout through it.
        return ctx;
    }

    fn defaultLibraryPathFn(ctx: *anyopaque) []const u8 {
        const self: *OsSystem = @ptrCast(@alignCast(ctx));
        return self.default_lib_path;
    }

    fn getCurrentDirectoryFn(ctx: *anyopaque) []const u8 {
        const self: *OsSystem = @ptrCast(@alignCast(ctx));
        return self.cwd;
    }

    fn writeOutputIsTTYFn(ctx: *anyopaque) bool {
        const self: *OsSystem = @ptrCast(@alignCast(ctx));
        return self.is_tty;
    }

    fn getWidthOfTerminalFn(ctx: *anyopaque) usize {
        const self: *OsSystem = @ptrCast(@alignCast(ctx));
        return self.term_width;
    }

    fn getEnvironmentVariableFn(ctx: *anyopaque, name: []const u8) ?[]const u8 {
        _ = ctx;
        // Zig 0.16: environment access requires Io. Fall back to null.
        _ = name;
        return null;
    }

    fn nowFn(ctx: *anyopaque) i64 {
        _ = ctx;
        // Zig 0.16 removed std.time.milliTimestamp. Use clock_gettime.
        var ts: std.os.linux.timespec = undefined;
        _ = std.os.linux.clock_gettime(.REALTIME, &ts);
        const ms: i64 = @intCast(@divTrunc(@as(i128, ts.sec) * std.time.ns_per_s + @as(i128, ts.nsec), std.time.ns_per_ms));
        return ms;
    }

    fn sinceStartFn(ctx: *anyopaque) i64 {
        const self: *OsSystem = @ptrCast(@alignCast(ctx));
        // Zig 0.16 removed std.time.nanoTimestamp. Use clock_gettime.
        var ts: std.os.linux.timespec = undefined;
        _ = std.os.linux.clock_gettime(.REALTIME, &ts);
        const now_ns: i128 = @as(i128, ts.sec) * std.time.ns_per_s + @as(i128, ts.nsec);
        const elapsed_ns: i128 = now_ns - self.start_ns;
        const elapsed_ms: i128 = @divTrunc(elapsed_ns, std.time.ns_per_ms);
        return @intCast(elapsed_ms);
    }
};

/// Detect terminal width via ioctl(TIOCGWINSZ) on POSIX, fall back to 80.
/// Implementation is intentionally defensive: any failure returns 80.
fn detectTerminalWidth() usize {
    if (@import("builtin").os.tag == .windows) {
        return 80;
    }

    const winsize = extern struct {
        ws_row: u16,
        ws_col: u16,
        ws_xpixel: u16,
        ws_ypixel: u16,
    };

    const TIOCGWINSZ: u32 = if (@import("builtin").os.tag == .linux or @import("builtin").os.tag == .freebsd or @import("builtin").os.tag == .openbsd or @import("builtin").os.tag == .netbsd) 0x5413 else 0x40087468; // darwin

    var ws: winsize = .{ .ws_row = 0, .ws_col = 0, .ws_xpixel = 0, .ws_ypixel = 0 };
    const fd: i32 = 1; // stdout
    const rc = std.posix.system.ioctl(fd, TIOCGWINSZ, @intFromPtr(&ws));
    if (std.posix.errno(rc) == .SUCCESS and ws.ws_col > 0) {
        return ws.ws_col;
    }
    return 80;
}
