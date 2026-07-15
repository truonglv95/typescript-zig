const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestCodeFixCannotFindModule_suggestion_falsePositive" {
    const content =
        \\// @moduleResolution: bundler
        \\// @module: commonjs
        \\// @resolveJsonModule: true
        \\// @strict: true
        \\// @Filename: /node_modules/foo/bar.json
        \\{ "a": 0 }
        \\// @Filename: /a.ts
        \\import abs = require([|"foo/bar.json"|]);
        \\abs;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
    _ = f.GoToFile(undefined, "/a.ts");
    _ = f.VerifySuggestionDiagnostics(undefined, null);
}

test "TestCompletionPropertyShorthandForObjectLiteral2" {
    const content =
        \\// @lib: es5
        \\const foo = 1;
        \\const bar = 2;
        \\const obj1 = {
        \\  foo b/*1*/
        \\};
        \\const obj2: any = {
        \\  foo b/*2*/
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"1"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionGlobalsPlus(
//                 &.{
//                     "bar",
//                     "foo",
//                     "obj2",
//                 }, false,
//             ),
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"2"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionGlobalsPlus(
//                 &.{
//                     "bar",
//                     "foo",
//                     "obj1",
//                 }, false,
//             ),
//         },
//     });
}

