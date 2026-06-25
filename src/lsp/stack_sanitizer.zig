const std = @import("std");

/// Replaces matches of genericSecretRegex with "X_X" followed by punctuation.
pub fn defeatGenericSecretRegex(allocator: std.mem.Allocator, s: []const u8) ![]u8 {
    var out = std.ArrayList(u8).init(allocator);
    errdefer out.deinit();

    const lower_s = try allocator.alloc(u8, s.len);
    defer allocator.free(lower_s);
    _ = std.ascii.lowerString(lower_s, s);

    var i: usize = 0;
    while (i < s.len) {
        var matched = false;
        const keywords = [_][]const u8{ "key", "token", "signature", "sig", "pwd" };
        const puncts = [_]u8{ '(', '[', '.', '|' };

        for (keywords) |kw| {
            if (i + kw.len < s.len and std.mem.startsWith(u8, lower_s[i..], kw)) {
                for (puncts) |p| {
                    if (s[i + kw.len] == p) {
                        try out.appendSlice(s[i .. i + kw.len]);
                        try out.appendSlice("X_X");
                        try out.append(p);
                        i += kw.len + 1;
                        matched = true;
                        break;
                    }
                }
                if (matched) break;
            }
        }

        if (!matched) {
            try out.append(s[i]);
            i += 1;
        }
    }

    return out.toOwnedSlice();
}

pub fn sanitizeStackTrace(allocator: std.mem.Allocator, stack: []const u8) ![]u8 {
    const start_idx = std.mem.indexOf(u8, stack, "runtime/debug.Stack()") orelse return try allocator.dupe(u8, "");
    const trimmed_stack = stack[start_idx..];

    var result = std.ArrayList(u8).init(allocator);
    defer result.deinit();

    var line_it = std.mem.splitScalar(u8, trimmed_stack, '\n');
    var is_first = true;

    while (line_it.next()) |line_raw| {
        if (!is_first) {
            try result.append('\n');
        }
        is_first = false;

        var i: usize = 0;
        while (i < line_raw.len and (line_raw[i] == ' ' or line_raw[i] == '\t')) : (i += 1) {}
        try result.appendSlice(line_raw[0..i]);

        const line = line_raw[i..];

        const our_module_idx = std.mem.indexOf(u8, line, "typescript-go/internal");
        if (our_module_idx) |idx| {
            try writeSanitizedModuleOrPath(line[idx..], &result);
        } else {
            try result.appendSlice("(REDACTED FRAME)");
        }
    }

    return defeatGenericSecretRegex(allocator, result.items);
}

fn writeSanitizedModuleOrPath(line_in: []const u8, result: *std.ArrayList(u8)) !void {
    var line = std.mem.trim(u8, line_in, " \t\r");

    if (std.mem.indexOf(u8, line, " +0x")) |idx| {
        line = line[0..idx];
    } else if (std.mem.lastIndexOf(u8, line, " in goroutine ")) |idx| {
        line = line[0..idx];
    }

    var seg_it = std.mem.splitScalar(u8, line, '/');
    var first = true;
    while (seg_it.next()) |segment_in| {
        if (!first) {
            try result.appendSlice("|>");
        }
        first = false;

        const segment = segment_in;
        if (std.mem.endsWith(u8, segment, ")")) {
            if (std.mem.lastIndexOfScalar(u8, segment, '(')) |open_idx| {
                try result.appendSlice(segment[0..open_idx]);
                try result.appendSlice("()");
                continue;
            } else {
                try result.appendSlice("???");
                continue;
            }
        }
        try result.appendSlice(segment);
    }
}

const testing = std.testing;

test "defeatGenericSecretRegex" {
    const allocator = testing.allocator;
    const input = "getSignatureHelp( Token[ pwd. key|";
    const res = try defeatGenericSecretRegex(allocator, input);
    defer allocator.free(res);
    try testing.expectEqualStrings("getSignatureX_XHelp( TokenX_X[ pwdX_X. keyX_X|", res);
}

test "sanitizeStackTrace" {
    const allocator = testing.allocator;
    const input =
        \\goroutine 1 [running]:
        \\runtime/debug.Stack()
        \\	/usr/local/go/src/runtime/debug/stack.go:26 +0x8e
        \\github.com/microsoft/typescript-go/internal/lsp.(*Server).recover(0xc0)
        \\	/workspaces/typescript-go/internal/lsp/server.go:777 +0x65
        \\panic({0x1, 0x2})
    ;
    const res = try sanitizeStackTrace(allocator, input);
    defer allocator.free(res);
    
    const expected = 
        \\runtime/debug.Stack()
        \\	(REDACTED FRAME)
        \\typescript-go|>internal|>lsp.(*Server).recover()
        \\	typescript-go|>internal|>lsp|>server.go:777
        \\(REDACTED FRAME)
    ;
    try testing.expectEqualStrings(expected, res);
}
