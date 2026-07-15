const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestRemoveDeclareFunctionExports" {
    const content =
        \\declare namespace M {
        \\    function RegExp2(pattern: string): RegExp2;
        \\    export function RegExp2(pattern: string, flags: string): RegExp2;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToBOF(undefined);
    _ = f.DeleteAtCaret(undefined, 8);
}

test "TestRenameJsPropertyAssignment4" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\function f() {
        \\   var /*1*/foo = this;
        \\   /*2*/foo.x = 1;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/a.js");
    // f.VerifyBaselineRename(undefined, null , "1", "2");
}

test "TestQuickInfoDisplayPartsExternalModuleAlias" {
    const content =
        \\// @Filename: quickInfoDisplayPartsExternalModuleAlias_file0.ts
        \\export namespace m1 {
        \\    export class c {
        \\    }
        \\}
        \\// @Filename: quickInfoDisplayPartsExternalModuleAlias_file1.ts
        \\import /*1*/a1 = require(/*mod1*/"./quickInfoDisplayPartsExternalModuleAlias_file0");
        \\new /*2*/a1.m1.c();
        \\export import /*3*/a2 = require(/*mod2*/"./quickInfoDisplayPartsExternalModuleAlias_file0");
        \\new /*4*/a2.m1.c();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestQuickInfoFromContextualUnionType1" {
    const content =
        \\// @strict: true
        \\// based on https://github.com/microsoft/TypeScript/issues/55495
        \\type X =
        \\  | {
        \\      name: string;
        \\      [key: string]: any;
        \\    }
        \\  | {
        \\      name: "john";
        \\      someProp: boolean;
        \\    };
        \\
        \\const obj = { name: "john", /*1*/someProp: "foo" } satisfies X;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "(property) someProp: string", "");
}

test "TestFindAllRefsImportDefault" {
    const content =
        \\// @Filename: f.ts
        \\export { foo as default };
        \\function /*start*/foo(a: number, b: number) {
        \\    return a + b;
        \\}
        \\// @Filename: b.ts
        \\import bar from "./f";
        \\bar(1, 2);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
    // f.VerifyBaselineFindAllReferences(undefined, "start");
}

test "TestJsdocLink1" {
    const content =
        \\class C {
        \\}
        \\/**
        \\ * {@link C}
        \\ * @wat Makes a {@link C}. A default one.
        \\ * {@link C()}
        \\ * {@link C|postfix text}
        \\ * {@link unformatted postfix text}
        \\ * @see {@link C} its great
        \\ */
        \\function /**/CC() {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestWhiteSpaceTrimming4" {
    const content =
        \\var re = /\w+   /*1*//;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, "\n");
    _ = f.VerifyCurrentFileContent(undefined, "var re = /\\w+\n    /;");
}

test "TestCompletionsUniqueSymbol1" {
    const content =
        \\declare const Symbol: () => symbol;
        \\namespace M {
        \\    export const sym = Symbol();
        \\}
        \\namespace N {
        \\    const sym = Symbol();
        \\    export interface I {
        \\        [sym]: number;
        \\        [M.sym]: number;
        \\    }
        \\}
        \\
        \\declare const i: N.I;
        \\i[|./**/|];
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
//                 &.{
//                     .Label =      "M",
//                     .InsertText = undefined("[M]"),
//                     .SortText =   undefined(string(ls.SortTextGlobalsOrKeywords)),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "M",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestReferencesForStringLiteralPropertyNames6" {
    const content =
        \\const x = function () { return 111111; }
        \\x./*1*/someProperty = 5;
        \\x["/*2*/someProperty"] = 3;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestCompletionAutoInsertQuestionDot" {
    const content =
        \\// @strict: true
        \\interface User {
        \\    address?: {
        \\        city: string;
        \\        "postal code": string;
        \\    }
        \\};
        \\declare const user: User;
        \\user.address[|./**/|]
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
//                 &.{
//                     .Label =      "city",
//                     .InsertText = undefined("?.city"),
//                     .Detail =     undefined("(property) city: string"),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "city",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =      "postal code",
//                     .InsertText = undefined("?.[\"postal code\"]"),
//                     .Detail =     undefined("(property) \"postal code\": string"),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "postal code",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

