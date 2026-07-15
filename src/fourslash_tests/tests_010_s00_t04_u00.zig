const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestSmartSelection_comment1" {
    const content =
        \\const a = 1; ///**/comment content
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineSelectionRanges(undefined);
}

test "TestSignatureHelpOptionalCall" {
    const content =
        \\function fnTest(str: string, num: number) { }
        \\fnTest?.(/*1*/);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // f.VerifySignatureHelp(undefined, .{.Text = "fnTest(str: string, num: number): void", .ParameterCount = 2, .ParameterName = "str", .ParameterSpan = "str: string"});
}

