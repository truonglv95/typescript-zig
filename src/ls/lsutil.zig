const std = @import("std");
pub const LSUtil = struct {};
pub const userpreferences = @import("lsutil/userpreferences.zig");
pub const UserPreferences = userpreferences.UserPreferences;
pub fn newDefaultUserPreferences() UserPreferences {
    return .{};
}
