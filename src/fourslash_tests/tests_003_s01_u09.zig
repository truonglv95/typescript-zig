const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestCompletionListAfterObjectLiteral1" {
    const content =
        \\var v = { x: 4, y: 3 }./**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "x",
//                 "y",
//             },
//         },
//     });
}

test "TestSyntacticClassificationsMergeConflictMarker1" {
    const content =
        \\<<<<<<< HEAD
        \\"AAAA"
        \\=======
        \\"BBBB"
        \\>>>>>>> Feature
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifySemanticTokens(undefined, &.{});
}

