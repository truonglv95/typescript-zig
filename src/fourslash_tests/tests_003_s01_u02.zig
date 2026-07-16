const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestCompletionListInUnclosedFunction08" {
    const content =
        \\function foo(x: string, y: number, z: boolean) {
        \\    function bar(a: number, b: string = "hello", c: typeof x = "hello") {
        \\        var v = /*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
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
//                 "c",
//             },
//         },
//     });
}

test "TestFindAllRefsRootSymbols" {
    const content =
        \\interface I { /*0*/x: {}; }
        \\interface J { /*1*/x: {}; }
        \\declare const o: (I | J) & { /*2*/x: string };
        \\o./*3*/x;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "0", "1", "2", "3");
}

