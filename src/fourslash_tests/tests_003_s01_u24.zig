const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestCompletionAfterNewline2" {
    const content =
        \\// @lib: es5
        \\let foo = 5 as const /*1*/
        \\/*2*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, "1", null);
    // f.VerifyCompletions(undefined, "2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionGlobalsPlus(
//                 &.{
//                     &.{
//                         .Label = "foo",
//                     },
//                 }, false,
//             ),
//         },
//     });
}

test "TestCodeFixSpellingCaseSensitive3" {
    const content =
        \\class Node {}
        \\let node = new Node();
        \\[|nodes|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyRangeAfterCodeFix(undefined, "node", false, 0, 0);
}

