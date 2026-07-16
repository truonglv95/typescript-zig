const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestFormatSelectionWithTrivia7" {
    const content =
        \\if (true) {
        \\/*begin*/// test comment/*end*/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatSelection(undefined, "begin", "end");
    try f.VerifyCurrentFileContent(undefined, "if (true) {\n    // test comment\n}");
}

test "TestInlayHintsInteractiveFunctionParameterTypes5" {
    const content =
        \\const foo: 1n = 1n;
        \\export function fn(b = foo) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayFunctionParameterTypeHints = core.TSTrue}});
}

