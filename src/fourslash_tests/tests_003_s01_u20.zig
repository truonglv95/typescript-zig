const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestCompletionListInUnclosedFunction05" {
    const content =
        \\function foo(x: string, y: number, z: boolean) {
        \\    function bar(a: number, b: string, c: typeof x = /*1*/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "foo",
//                 "x",
//                 "y",
//                 "z",
//                 "bar",
//                 "a",
//                 "b",
//             },
//         },
//     });
}

test "TestJsdocSatisfiesTagCompletion2" {
    const content =
        \\// @noEmit: true
        \\// @allowJS: true
        \\// @checkJs: true
        \\// @filename: /a.js
        \\/**
        \\ * @/**/
        \\ */
        \\const t = { a: 1 };
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
//             .Includes = &.{
//                 "satisfies",
//             },
//         },
//     });
}

