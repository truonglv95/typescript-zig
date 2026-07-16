const std = @import("std");
const testing = std.testing;

const baseline = @import("../testutil/baseline/baseline.zig");
const stack_sanitizer = @import("stack_sanitizer.zig");

// This test uses non-trimmed paths to emulate debug builds.
// Most users won't actually see this.
test "SanitizedDebugStackTraceCompletionsRequest" {
    const allocator = std.testing.allocator;

    const input =
        "goroutine 1196 [running]:\n" ++
        "runtime/debug.Stack()\n" ++
        "        /usr/local/go/src/runtime/debug/stack.go:26 +0x8e\n" ++
        "github.com/microsoft/typescript-go/internal/lsp.(*Server).recover(0xc0001dae08, {0x14bc418, 0xc00bc60960}, 0xc00baf16e0)\n" ++
        "        /workspaces/typescript-go/internal/lsp/server.go:777 +0x65\n" ++
        "panic({0x1077b40?, 0x1abcb70?})\n" ++
        "        /usr/local/go/src/runtime/panic.go:783 +0x136\n" ++
        "github.com/microsoft/typescript-go/internal/ls.(*LanguageService).getCompletionData.func15()\n" ++
        "        /workspaces/typescript-go/internal/ls/completions.go:1303 +0xfa\n" ++
        "github.com/microsoft/typescript-go/internal/ls.(*LanguageService).getCompletionData.func18()\n" ++
        "        /workspaces/typescript-go/internal/ls/completions.go:1548 +0x2df\n" ++
        "github.com/microsoft/typescript-go/internal/ls.(*LanguageService).getCompletionData(0xc004b08240, {0x14bc418, 0xc00bc60a20}, 0xc0069ef908, 0xc000272008, 0x1b, 0xc002b28e00)\n" ++
        "        /workspaces/typescript-go/internal/ls/completions.go:1581 +0x2b92\n" ++
        "github.com/microsoft/typescript-go/internal/ls.(*LanguageService).getCompletionsAtPosition(0xc004b08240, {0x14bc418, 0xc00bc60a20}, 0xc000272008, 0x1b, 0x0)\n" ++
        "        /workspaces/typescript-go/internal/ls/completions.go:347 +0x690\n" ++
        "github.com/microsoft/typescript-go/internal/ls.(*LanguageService).ProvideCompletion(0xc004b08240, {0x14bc418, 0xc00bc60a20}, {0xc0092e02a0, 0x28}, {0x2, 0x4}, 0xc004580c30)\n" ++
        "        /workspaces/typescript-go/internal/ls/completions.go:47 +0x207\n" ++
        "github.com/microsoft/typescript-go/internal/lsp.(*Server).handleCompletion(0xc0001dae08, {0x14bc418, 0xc00bc60960}, 0xc004b08240, 0xc00baf14d0)\n" ++
        "        /workspaces/typescript-go/internal/lsp/server.go:1102 +0xe5\n" ++
        "github.com/microsoft/typescript-go/internal/lsp.registerLanguageServiceWithAutoImportsRequestHandler[...].func1({0x14bc418, 0xc00bc60960}, 0xc00baf16e0)\n" ++
        "        /workspaces/typescript-go/internal/lsp/server.go:682 +0x32a\n" ++
        "github.com/microsoft/typescript-go/internal/lsp.(*Server).handleRequestOrNotification(0xc0001dae08, {0x14bc418, 0xc00bc60960}, 0xc00baf16e0)\n" ++
        "        /workspaces/typescript-go/internal/lsp/server.go:531 +0x11e\n" ++
        "github.com/microsoft/typescript-go/internal/lsp.(*Server).dispatchLoop.func1()\n" ++
        "        /workspaces/typescript-go/internal/lsp/server.go:414 +0x65\n" ++
        "created by github.com/microsoft/typescript-go/internal/lsp.(*Server).dispatchLoop in goroutine 19\n" ++
        "        /workspaces/typescript-go/internal/lsp/server.go:438 +0x60";

    const sanitized = try stack_sanitizer.sanitizeStackTrace(allocator, input);
    defer allocator.free(sanitized);

    const actual = try sanitizedStackTraceBaselineContents(allocator, "TestSanitizedDebugStackTraceCompletionsRequest", input, sanitized);
    defer allocator.free(actual);

    try baseline.run(allocator, "completionsDebugStackTrace.md", actual, .{ .subfolder = "lsp/stackSanitizer/" });
}

test "SanitizedReleaseStackTraceCompletionsRequest" {
    const allocator = std.testing.allocator;

    const input =
        "runtime error: invalid memory address or nil pointer dereference\n" ++
        "goroutine 2331 [running]:\n" ++
        "runtime/debug.Stack()\n" ++
        "\truntime/debug/stack.go:26 +0x5e\n" ++
        "github.com/microsoft/typescript-go/internal/lsp.(*Server).recover(0xc0001c6e08, {0x441ae5?, 0xc000e976c0?}, 0xc00ab6c7b0)\n" ++
        "\tgithub.com/microsoft/typescript-go/internal/lsp/server.go:777 +0x58\n" ++
        "panic({0xc323a0?, 0x1780b90?})\n" ++
        "\truntime/panic.go:783 +0x132\n" ++
        "github.com/microsoft/typescript-go/internal/ls.(*LanguageService).getCompletionData.func15()\n" ++
        "\tgithub.com/microsoft/typescript-go/internal/ls/completions.go:1303 +0xba\n" ++
        "github.com/microsoft/typescript-go/internal/ls.(*LanguageService).getCompletionData.func18(...)\n" ++
        "\tgithub.com/microsoft/typescript-go/internal/ls/completions.go:1548\n" ++
        "github.com/microsoft/typescript-go/internal/ls.(*LanguageService).getCompletionData(0xc008329200, {0x10f6688, 0xc00c2871d0}, 0xc00190b308, 0xc0001fe008, 0x1b, 0xc0008a2f00)\n" ++
        "\tgithub.com/microsoft/typescript-go/internal/ls/completions.go:1581 +0x1ed4\n" ++
        "github.com/microsoft/typescript-go/internal/ls.(*LanguageService).getCompletionsAtPosition(0xc008329200, {0x10f6688, 0xc00c2871d0}, 0xc0001fe008, 0x1b, 0x0)\n" ++
        "\tgithub.com/microsoft/typescript-go/internal/ls/completions.go:347 +0x35f\n" ++
        "github.com/microsoft/typescript-go/internal/ls.(*LanguageService).ProvideCompletion(0xc008329200, {0x10f6688, 0xc00c287110}, {0xc00b472030?, 0xc00c287110?}, {0xb472030?, 0xc0?}, 0xc00c3ea000)\n" ++
        "\tgithub.com/microsoft/typescript-go/internal/ls/completions.go:47 +0x11c\n" ++
        "github.com/microsoft/typescript-go/internal/lsp.(*Server).handleCompletion(0x418834?, {0x10f6688?, 0xc00c287110?}, 0xc00b472030?, 0x10f6688?)\n" ++
        "\tgithub.com/microsoft/typescript-go/internal/lsp/server.go:1105 +0x39\n" ++
        "github.com/microsoft/typescript-go/internal/lsp.init.func1.registerLanguageServiceWithAutoImportsRequestHandler[...].28({0x10f6688, 0xc00c287110}, 0xc00ab6c7b0)\n" ++
        "\tgithub.com/microsoft/typescript-go/internal/lsp/server.go:682 +0x16c\n" ++
        "github.com/microsoft/typescript-go/internal/lsp.(*Server).handleRequestOrNotification(0xc0001c6e08, {0x10f66c0?, 0xc006589180?}, 0xc00ab6c7b0)\n" ++
        "\tgithub.com/microsoft/typescript-go/internal/lsp/server.go:531 +0x1c6\n" ++
        "github.com/microsoft/typescript-go/internal/lsp.(*Server).dispatchLoop.func1()\n" ++
        "\tgithub.com/microsoft/typescript-go/internal/lsp/server.go:414 +0x3a\n" ++
        "created by github.com/microsoft/typescript-go/internal/lsp.(*Server).dispatchLoop in goroutine 35\n" ++
        "\tgithub.com/microsoft/typescript-go/internal/lsp/server.go:438 +0x9f1";

    const sanitized = try stack_sanitizer.sanitizeStackTrace(allocator, input);
    defer allocator.free(sanitized);

    const actual = try sanitizedStackTraceBaselineContents(allocator, "TestSanitizedReleaseStackTraceCompletionsRequest", input, sanitized);
    defer allocator.free(actual);

    try baseline.run(allocator, "completionsReleaseStackTrace.md", actual, .{ .subfolder = "lsp/stackSanitizer/" });
}

fn sanitizedStackTraceBaselineContents(allocator: std.mem.Allocator, name: []const u8, input: []const u8, output: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, "Test name: `{s}`\n\n# Unsanitized input:\n\n````\n{s}\n````\n\n# Sanitized output:\n\n````\n{s}\n````\n", .{ name, input, output });
}

// VS Code's telemetry pipeline check. In Go they used regexp.
test "SanitizedStackTraceDefeatsVSCodeGenericSecretRegex" {
    const allocator = std.testing.allocator;

    const input =
        "goroutine 7 [running]:\n" ++
        "runtime/debug.Stack()\n" ++
        "\truntime/debug/stack.go:26 +0x5e\n" ++
        "github.com/microsoft/typescript-go/internal/ls.(*LanguageService).getSignatureHelp(0x1)\n" ++
        "\tgithub.com/microsoft/typescript-go/internal/ls/signature.go:42 +0x10\n" ++
        "github.com/microsoft/typescript-go/internal/ls.LookupKey(0x2)\n" ++
        "\tgithub.com/microsoft/typescript-go/internal/ls/keys.go:7 +0x10\n" ++
        "github.com/microsoft/typescript-go/internal/ls.validateToken(0x3)\n" ++
        "\tgithub.com/microsoft/typescript-go/internal/ls/token.go:9 +0x10\n" ++
        "github.com/microsoft/typescript-go/internal/ls.signRequest(0x4)\n" ++
        "\tgithub.com/microsoft/typescript-go/internal/ls/sig.go:11 +0x10\n" ++
        "github.com/microsoft/typescript-go/internal/ls.setPwd(0x5)\n" ++
        "\tgithub.com/microsoft/typescript-go/internal/ls/pwd.go:13 +0x10";

    const output = try stack_sanitizer.sanitizeStackTrace(allocator, input);
    defer allocator.free(output);

    const lower_output = try std.ascii.allocLowerString(allocator, output);
    defer allocator.free(lower_output);

    const words = [_][]const u8{ "key", "token", "sig", "secret", "signature", "password", "passwd", "pwd", "android:value" };
    for (words) |w| {
        if (std.mem.indexOf(u8, lower_output, w)) |idx| {
            if (idx + w.len < lower_output.len) {
                const c = lower_output[idx + w.len];
                if (!std.ascii.isAlphanumeric(c)) {
                    std.debug.panic("sanitized stack trace would be redacted by VS Code's Generic Secret regex at index {d}: {s}\n", .{ idx, output });
                }
            }
        }
    }

    const actual = try sanitizedStackTraceBaselineContents(allocator, "TestSanitizedStackTraceDefeatsVSCodeGenericSecretRegex", input, output);
    defer allocator.free(actual);

    try baseline.run(allocator, "genericSecretWorkaround.md", actual, .{ .subfolder = "lsp/stackSanitizer/" });
}
