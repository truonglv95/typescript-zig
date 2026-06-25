const std = @import("std");

var failing_tests_set: ?std.StringHashMap(void) = null;
var failing_tests_mutex = std.Thread.Mutex{};

/// skipIfFailing checks if the current test is in the failingTests.txt file
/// and skips it unless the TSGO_FOURSLASH_IGNORE_FAILING environment variable is set.
/// This allows tests to be marked as failing without modifying the test files themselves.
pub fn skipIfFailing(allocator: std.mem.Allocator, test_name: []const u8) !void {
    if (std.posix.getenv("TSGO_FOURSLASH_IGNORE_FAILING") != null) {
        return;
    }

    failing_tests_mutex.lock();
    defer failing_tests_mutex.unlock();

    if (failing_tests_set == null) {
        var set = std.StringHashMap(void).init(allocator);

        const file_path = "src/fourslash/_scripts/failingTests.txt";
        
        if (std.fs.cwd().openFile(file_path, .{})) |file| {
            defer file.close();
            var buf_reader = std.io.bufferedReader(file.reader());
            var in_stream = buf_reader.reader();

            var buf: [1024]u8 = undefined;
            while (in_stream.readUntilDelimiterOrEof(&buf, '\n') catch null) |line| {
                const trimmed = std.mem.trim(u8, line, " \r\n\t");
                if (trimmed.len > 0) {
                    const dupe = allocator.dupe(u8, trimmed) catch trimmed;
                    set.put(dupe, {}) catch {};
                }
            }
        } else |err| {
            // If the file cannot be found, we just proceed with an empty set.
            _ = err;
        }

        failing_tests_set = set;
    }

    if (failing_tests_set.?.contains(test_name)) {
        return error.SkipZigTest;
    }
}
