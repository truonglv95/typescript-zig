const std = @import("std");
const builtin = @import("builtin");

fn isASCII(s: []const u8) bool {
    for (s) |c| {
        if (c >= 0x80) return false;
    }
    return true;
}

fn normalizeNFCMacOS(allocator: std.mem.Allocator, s: []const u8) ![]const u8 {
    if (isASCII(s)) {
        return try allocator.dupe(u8, s);
    }

    const lib = std.c.dlopen("/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation", std.c.RTLD.LAZY) orelse return try allocator.dupe(u8, s);
    defer _ = std.c.dlclose(lib);

    const CFStringCreateWithCString = @as(?*const fn(?*anyopaque, [*c]const u8, u32) callconv(.C) ?*anyopaque, @ptrCast(std.c.dlsym(lib, "CFStringCreateWithCString"))) orelse return try allocator.dupe(u8, s);
    const CFStringCreateMutableCopy = @as(?*const fn(?*anyopaque, isize, *anyopaque) callconv(.C) ?*anyopaque, @ptrCast(std.c.dlsym(lib, "CFStringCreateMutableCopy"))) orelse return try allocator.dupe(u8, s);
    const CFStringNormalize = @as(?*const fn(*anyopaque, u32) callconv(.C) void, @ptrCast(std.c.dlsym(lib, "CFStringNormalize"))) orelse return try allocator.dupe(u8, s);
    const CFStringGetCString = @as(?*const fn(*anyopaque, [*c]u8, isize, u32) callconv(.C) u8, @ptrCast(std.c.dlsym(lib, "CFStringGetCString"))) orelse return try allocator.dupe(u8, s);
    const CFRelease = @as(?*const fn(*anyopaque) callconv(.C) void, @ptrCast(std.c.dlsym(lib, "CFRelease"))) orelse return try allocator.dupe(u8, s);
    const CFStringGetLength = @as(?*const fn(*anyopaque) callconv(.C) isize, @ptrCast(std.c.dlsym(lib, "CFStringGetLength"))) orelse return try allocator.dupe(u8, s);

    const kCFStringEncodingUTF8: u32 = 0x08000100;
    const kCFStringNormalizationFormC: u32 = 2;

    const cstr = try allocator.dupeZ(u8, s);
    defer allocator.free(cstr);

    const src = CFStringCreateWithCString(null, cstr.ptr, kCFStringEncodingUTF8);
    if (src == null) return try allocator.dupe(u8, s);
    defer CFRelease(src.?);

    const mutable = CFStringCreateMutableCopy(null, 0, src.?);
    if (mutable == null) return try allocator.dupe(u8, s);
    defer CFRelease(mutable.?);

    CFStringNormalize(mutable.?, kCFStringNormalizationFormC);

    const maxLen = @as(usize, @intCast(CFStringGetLength(mutable.?))) * 4 + 1;
    const buf = try allocator.alloc(u8, maxLen);
    errdefer allocator.free(buf);

    if (CFStringGetCString(mutable.?, buf.ptr, @intCast(maxLen), kCFStringEncodingUTF8) != 0) {
        const len = std.mem.indexOfScalar(u8, buf, 0) orelse buf.len;
        const result = try allocator.dupe(u8, buf[0..len]);
        allocator.free(buf);
        return result;
    }

    allocator.free(buf);
    return try allocator.dupe(u8, s);
}

// canonicalizePath returns the path in the form the library uses for
// internal bookkeeping and event delivery.
pub fn canonicalizePath(allocator: std.mem.Allocator, p: []const u8) ![]const u8 {
    if (builtin.os.tag == .macos) {
        return try normalizeNFCMacOS(allocator, p);
    }
    return try allocator.dupe(u8, p);
}
