pub const tsc_module = @import("tsc.zig");

pub const watcher = @import("watcher.zig");
pub const tsc = struct {
    pub const diagnostics = @import("tsc/diagnostics.zig");
};
pub const build = @import("build/build.zig");
pub const incremental = @import("incremental/incremental.zig");
