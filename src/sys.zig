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
        // Read the real process working directory instead of a hard-coded path.
        var cwd_buf: [std.fs.max_path_bytes]u8 = undefined;
        const cwd = std.process.getCwd(&cwd_buf) catch ".";
        const cwd_dup = allocator.dupe(u8, cwd) catch ".";

        // Lib path: prefer $TYPESCRIPT_ZIG_LIB_PATH, otherwise empty (caller
        // resolves via install dir layout).
        const env_lib = std.process.getEnvVarOwned(allocator, "TYPESCRIPT_ZIG_LIB_PATH") catch null;

        const is_tty = std.fs.File.stdout().isTty();

        return .{
            .allocator = allocator,
            .cwd = cwd_dup,
            .default_lib_path = if (env_lib) |p| p else "",
            .start_ns = std.time.nanoTimestamp(),
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
        // Returns a pointer owned by the process environment; lifetime is the
        // process lifetime. Caller must not free.
        return std.process.getEnvVarOwned(std.heap.page_allocator, name) catch null;
    }

    fn nowFn(ctx: *anyopaque) i64 {
        _ = ctx;
        return @intCast(std.time.milliTimestamp());
    }

    fn sinceStartFn(ctx: *anyopaque) i64 {
        const self: *OsSystem = @ptrCast(@alignCast(ctx));
        const now = std.time.nanoTimestamp();
        const elapsed_ns: i128 = now - self.start_ns;
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
