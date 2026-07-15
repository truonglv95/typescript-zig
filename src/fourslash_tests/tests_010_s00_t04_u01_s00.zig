const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestCompletionsInExport_moduleBlock" {
    const content =
        \\const outOfScope = 0;
        \\
        \\declare module 'mod' {
        \\  const a: string;
        \\  type T = number;
        \\  export { /**/ };
        \\}
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
//                 "a",
//                 "T",
//                 &.{
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
    _ = f.Insert(undefined, "a, ");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "T",
//                 &.{
//                     .Label =      "a?",
//                     .InsertText = undefined("a"),
//                     .FilterText = undefined("a"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//                 &.{
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
    _ = f.Insert(undefined, "T as ");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{},
//         },
//     });
    _ = f.Insert(undefined, "U, ");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "T",
//                 &.{
//                     .Label =      "a?",
//                     .InsertText = undefined("a"),
//                     .FilterText = undefined("a"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//                 &.{
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
    _ = f.Insert(undefined, "T, ");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =      "a?",
//                     .InsertText = undefined("a"),
//                     .FilterText = undefined("a"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//                 &.{
//                     .Label =      "T?",
//                     .InsertText = undefined("T"),
//                     .FilterText = undefined("T"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//                 &.{
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

