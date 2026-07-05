const std = @import("std");

// We default to embed for Zig port, mimicking how Go works with go:embed.
pub const embed = @import("embed.zig");

pub const Embedded = embed.embedded;
pub const embedded = Embedded;
pub const LibNames = @import("libs_generated.zig").LibNames;

pub fn WrapFS(fs: anytype) @TypeOf(fs) {
    return embed.wrapFS(fs);
}

pub fn LibPath() []const u8 {
    return embed.libPath();
}

pub fn TestingLibPath() []const u8 {
    return "src/bundled/libs";
}

pub const IsBundled = embed.IsBundled;
