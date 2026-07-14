const std = @import("std");
const posix = std.posix;

pub fn reclenOf(d: *const anyopaque) u16 {
    _ = d;
    return 0;
}

pub fn inoOf(d: *const anyopaque) u64 {
    _ = d;
    return 0;
}
