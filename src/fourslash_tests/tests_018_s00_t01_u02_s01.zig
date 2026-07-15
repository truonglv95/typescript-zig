const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestCompletionListClassPrivateFields" {
    const content =
        \\class A {
        \\    #private = 1;
        \\}
        \\
        \\class B extends A {
        \\    /**/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionClassElementKeywords,
//         },
//     });
}

