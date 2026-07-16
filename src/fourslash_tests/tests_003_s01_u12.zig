const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestQuickInfoOnElementAccessInWriteLocation2" {
    const content =
        \\// @strict: true
        \\// @exactOptionalPropertyTypes: true
        \\declare const xx: { prop?: number };
        \\xx['prop'/*1*/] += 1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "(property) prop?: number", "");
}

test "TestCompletionListInClosedFunction02" {
    const content =
        \\function foo(x: string, y: number, z: boolean) {
        \\    function bar(a: number, b: string, c: typeof /*1*/) {
        \\    }
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

