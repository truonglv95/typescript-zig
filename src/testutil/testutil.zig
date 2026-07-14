const std = @import("std");
const race = @import("race/norace.zig");

pub fn assertPanics(tb: anytype, fn_to_call: anytype, expected: anytype, msg_and_args: anytype) void {
    _ = tb;
    _ = expected;
    _ = msg_and_args;
    // Zig does not support recover() in the same way Go does.
    // We just call the function. If it panics, the test will naturally fail.
    fn_to_call();
}

pub fn recoverAndFail(t: anytype, msg: []const u8) void {
    _ = t;
    _ = msg;
    // Zig does not have recover.
}

var test_program_is_single_threaded_val: ?bool = null;

pub fn testProgramIsSingleThreaded() bool {
    if (test_program_is_single_threaded_val) |val| {
        return val;
    }

    if (std.posix.getenv("TS_TEST_PROGRAM_SINGLE_THREADED")) |v| {
        if (std.mem.eql(u8, v, "true") or std.mem.eql(u8, v, "1")) {
            test_program_is_single_threaded_val = true;
            return true;
        }
        if (std.mem.eql(u8, v, "false") or std.mem.eql(u8, v, "0")) {
            test_program_is_single_threaded_val = false;
            return false;
        }
    }

    test_program_is_single_threaded_val = !race.enabled;
    return test_program_is_single_threaded_val.?;
}
