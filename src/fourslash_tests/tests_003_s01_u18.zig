const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestCompletionsRecommended_namespace" {
    const content =
        \\// @noLib: true
        \\// @Filename: /a.ts
        \\export namespace Name {
        \\    export class C {}
        \\}
        \\export function f(c: Name.C) {}
        \\f(new N/*a0*/);
        \\f(new /*a1*/);
        \\// @Filename: /b.ts
        \\import { f } from "./a";
        \\f(new N/*b0*/);
        \\f(new /*b1*/);
        \\// @Filename: /c.ts
        \\import * as alpha from "./a";
        \\alpha.f(new a/*c0*/);
        \\alpha.f(new /*c1*/);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"a0", "a1"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =     "Name",
//                     .Detail =    undefined("namespace Name"),
//                     .Kind =      undefined(lsproto.CompletionItemKindModule),
//                     .Preselect = undefined(true),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"b0", "b1"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label = "Name",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./a",
//                         },
//                     },
//                     .Detail =              undefined("namespace Name"),
//                     .Kind =                undefined(lsproto.CompletionItemKindModule),
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .Preselect =           undefined(true),
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"c0", "c1"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =     "alpha",
//                     .Detail =    undefined("import alpha"),
//                     .Kind =      undefined(lsproto.CompletionItemKindVariable),
//                     .Preselect = undefined(true),
//                 },
//             },
//         },
//     });
}

test "TestDeduplicateDuplicateMergedBindCheckErrors" {
    const content =
        \\class X {
        \\  foo() {
        \\      return 1;
        \\  }
        \\  get foo() {
        \\      return 1;
        \\  }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 2);
}

