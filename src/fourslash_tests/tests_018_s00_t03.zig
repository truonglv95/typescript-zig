const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestFormattingAfterMultiLineIfCondition" {
    const content =
        \\ var foo;
        \\ if (foo &&
        \\     foo) {
        \\/*comment*/     // This is a comment
        \\     foo.toString();
        \\ /**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, "}");
    _ = f.GoToMarker(undefined, "comment");
    try f.VerifyCurrentLineContent(undefined, "    // This is a comment");
}

test "TestCompletionListInImportClause04" {
    const content =
        \\// @Filename: foo.d.ts
        \\ declare class Foo {
        \\     static prop1(x: number): number;
        \\     static prop1(x: string): string;
        \\     static prop2(x: boolean): boolean;
        \\ }
        \\ export = Foo; /*2*/
        \\// @Filename: app.ts
        \\import {/*1*/} from './foo';
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
//             .Unsorted = &.{
//                 "prototype",
//                 "prop1",
//                 "prop2",
//                 &.{
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
    try f.VerifyNoErrors(undefined);
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyNoErrors(undefined);
}

test "TestConstEnumQuickInfoAndCompletionList" {
    const content =
        \\const enum /*1*/e {
        \\    a,
        \\    b,
        \\    c
        \\}
        \\/*2*/e.a;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "e",
//                     .Detail = undefined("const enum e"),
//                 },
//             },
//         },
//     });
    try f.VerifyQuickInfoAt(undefined, "1", "const enum e", "");
    try f.VerifyQuickInfoAt(undefined, "2", "const enum e", "");
}

test "TestDocumentHighlightsTypeParameterInHeritageClause01" {
    const content =
        \\// @lib: es5
        \\interface I<[|T|]> extends I<[|T|]>, [|T|] {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestImportNameCodeFixInferEndingPreference" {
    const content =
        \\// @module: esnext
        \\// @moduleResolution: bundler
        \\// @Filename: /a.mts
        \\export {};
        \\// @Filename: /b.ts
        \\export {};
        \\// @Filename: /c.ts
        \\export const c = 0;
        \\// @Filename: /main.ts
        \\import {} from "./a.mjs";
        \\import {} from "./b";
        \\
        \\c/**/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"./c"}, null );
}

test "TestUnusedImports10FS" {
    const content =
        \\// @noUnusedLocals: true
        \\namespace A {
        \\   export class Calculator {
        \\        public handelChar() {
        \\        }
        \\    }
        \\}
        \\namespace B {
        \\    [|import a = A;|]
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyRangeAfterCodeFix(undefined, "", false, 0, 0);
}

test "TestCompletions03" {
    const content =
        \\// @lib: es5
        \\interface Foo {
        \\   one: any;
        \\   two: any;
        \\   three: any;
        \\}
        \\
        \\let x: Foo = {
        \\    get one() { return "" },
        \\    set two(t) {},
        \\    /**/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "three",
//             },
//         },
//     });
}

test "TestFindAllRefsMappedType_nonHomomorphic" {
    const content =
        \\// @strict: true
        \\function f(x: { [K in "m"]: number; }) {
        \\    x./*1*/m;
        \\    x./*2*/m
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestInlayHintsInteractiveMultifileFunctionCalls" {
    const content =
        \\// @Target: esnext
        \\// @module: node18
        \\// @Filename: aaa.mts
        \\import { helperB } from "./bbb.mjs";
        \\helperB("hello, world!");
        \\// @Filename: bbb.mts
        \\import { helperC } from "./ccc.mjs";
        \\export function helperB(bParam: string) {
        \\    helperC(bParam);
        \\}
        \\// @Filename: ccc.mts
        \\export function helperC(cParam: string) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "./aaa.mts");
    // try f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayParameterNameHints = lsutil.IncludeInlayParameterNameHintsAll}});
}

test "TestModuleMembersOfGenericType" {
    const content =
        \\namespace M {
        \\    export var x = <T>(x: T) => x;
        \\}
        \\var r = M./**/;
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
//                     .Label =  "x",
//                     .Detail = undefined("var M.x: <T>(x: T) => T"),
//                 },
//             },
//         },
//     });
}

