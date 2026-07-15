const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestCompletionsWithDeprecatedTag10" {
    const content =
        \\// @Filename: /foo.ts
        \\/** @deprecated foo */
        \\export const foo = 0;
        \\// @Filename: /index.ts
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
//                     .Label = "foo",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./foo",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .Kind =                undefined(lsproto.CompletionItemKindVariable),
//                     .SortText =            undefined(string(ls.DeprecateSortText(ls.SortTextAutoImportSuggestions))),
//                     .Tags =                &&.{lsproto.CompletionItemTagDeprecated},
//                 },
//             },
//         },
//     });
}

test "TestSignatureHelpTaggedTemplatesNegatives4" {
    const content =
        \\function foo(strs, ...rest) {
        \\}
        \\
        \\/*1*/fo/*2*/o /*3*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyNoSignatureHelpForMarkers(undefined, f.MarkerNames());
}

