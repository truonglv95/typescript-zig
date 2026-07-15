const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestCompletionOfInterfaceAndVar" {
    const content =
        \\// @lib: es5
        \\interface AnalyserNode {
        \\}
        \\declare var AnalyserNode: {
        \\    prototype: AnalyserNode;
        \\    new(): AnalyserNode;
        \\};
        \\/**/
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
//                 &.{
//                     .Label =  "AnalyserNode",
//                     .Detail = undefined("interface AnalyserNode\nvar AnalyserNode: {\n    new (): AnalyserNode;\n    prototype: AnalyserNode;\n}"),
//                     .Kind =   undefined(lsproto.CompletionItemKindVariable),
//                 },
//             },
//         },
//     });
}

test "TestCompletionListInUnclosedTypeOfExpression02" {
    const content =
        \\var x;
        \\var y = (p) => typeof /*1*/
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
//                 "x",
//                 "p",
//             },
//         },
//     });
}

