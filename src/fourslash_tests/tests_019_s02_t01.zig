const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestFormattingOnModuleIndentation" {
    const content =
        \\  namespace     Foo    {
        \\    export    namespace    A  .   B  .   C     {      }/**/
        \\               }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToBOF(undefined);
    try f.VerifyCurrentLineContent(undefined, "namespace Foo {");
    _ = f.GoToMarker(undefined, "");
    try f.VerifyCurrentLineContent(undefined, "    export namespace A.B.C { }");
    _ = f.GoToEOF(undefined);
    try f.VerifyCurrentLineContent(undefined, "}");
}

test "TestFormattingMultilineCommentsWithTabs1" {
    const content =
        \\var f = function (j) {
        \\
        \\    switch (j) {
        \\        case 1:
        \\/*1*/                /* when current checkbox has focus, Firefox has changed check state already
        \\/*2*/                on SPACE bar press only
        \\/*3*/                IE does not have issue, use the CSS class
        \\/*4*/                input:focus[type=checkbox] (z-index = 31290)
        \\/*5*/                to determine whether checkbox has focus or not
        \\                */
        \\            break;
        \\        case 2:
        \\        break;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCurrentLineContent(undefined, "            /* when current checkbox has focus, Firefox has changed check state already");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyCurrentLineContent(undefined, "            on SPACE bar press only");
    _ = f.GoToMarker(undefined, "3");
    try f.VerifyCurrentLineContent(undefined, "            IE does not have issue, use the CSS class");
    _ = f.GoToMarker(undefined, "4");
    try f.VerifyCurrentLineContent(undefined, "            input:focus[type=checkbox] (z-index = 31290)");
    _ = f.GoToMarker(undefined, "5");
    try f.VerifyCurrentLineContent(undefined, "            to determine whether checkbox has focus or not");
}

test "TestGetOutliningForObjectDestructuring" {
    const content =
        \\const[| {
        \\    a,
        \\    b,
        \\    c
        \\}|] =[| {
        \\    a: 1,
        \\    b: 2,
        \\    c: 3
        \\}|]
        \\const[| {
        \\    a:[| {
        \\        a_1,
        \\        a_2,
        \\        a_3:[| {
        \\            a_3_1,
        \\            a_3_2,
        \\            a_3_3,
        \\        }|],
        \\    }|],
        \\    b,
        \\    c
        \\}|] =[| {
        \\    a:[| {
        \\        a_1: 1,
        \\        a_2: 2,
        \\        a_3:[| {
        \\            a_3_1: 1,
        \\            a_3_2: 1,
        \\            a_3_3: 1
        \\        }|],
        \\    }|],
        \\    b: 2,
        \\    c: 3
        \\}|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyOutliningSpans(undefined);
}

test "TestCodeFixInferFromUsageVariable3JS" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @noEmit: true
        \\// @noImplicitAny: false
        \\// @Filename: important.js
        \\[|function f(foo) {
        \\    foo += 2
        \\    return foo
        \\}|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyRangeAfterCodeFix(undefined, "/** \n * @param {number} foo\n */\nfunction f(foo) {\n    foo += 2\n    return foo\n}\n", false, 0, 0);
}

test "TestSemanticClassificationAlias" {
    const content =
        \\// @Filename: /a.ts
        \\export type x = number;
        \\export class y {};
        \\// @Filename: /b.ts
        \\import { /*0*/x, /*1*/y } from "./a";
        \\const v: /*2*/x = /*3*/y;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/b.ts");
    // try f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "variable.declaration.readonly", .Text = "v"},
//         .{.Type = "type", .Text = "x"},
//         .{.Type = "class", .Text = "y"},
//     });
}

test "TestFindAllRefsImportEquals" {
    const content =
        \\import j = N./**/q;
        \\namespace N { export const q = 0; }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "");
}

test "TestAutoImportVerbatimTypeOnly1" {
    const content =
        \\// @module: node18
        \\// @verbatimModuleSyntax: true
        \\// @Filename: /mod.ts
        \\export const value = 0;
        \\export class C { constructor(v: any) {} }
        \\export interface I {}
        \\// @Filename: /a.mts
        \\const x: /**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyApplyCodeActionFromCompletion(undefined, undefined(""), &.{
//         .Name =        "I",
//         .Source =      "./mod",
//         .Description = "Add import from \"./mod.js\"",
//         .AutoImportFix = &.{
//             .ModuleSpecifier = "./mod.js",
//         },
//         .NewFileContent = undefined("import type { I } from \"./mod.js\";\n\nconst x: "),
//     });
    _ = f.Insert(undefined, "I = new C");
    // try f.VerifyApplyCodeActionFromCompletion(undefined, null, &.{
//         .Name =        "C",
//         .Source =      "./mod",
//         .Description = "Update import from \"./mod.js\"",
//         .AutoImportFix = &.{
//             .ModuleSpecifier = "./mod.js",
//         },
//         .NewFileContent = undefined("import { C, type I } from \"./mod.js\";\n\nconst x: I = new C"),
//     });
}

test "TestQuickInfoJsDocNonDiscriminatedUnionSharedProp" {
    const content =
        \\// @strict: false
        \\interface Entries {
        \\  /**
        \\   * Plugins info...
        \\   */
        \\  plugins?: Record<string, Record<string, unknown>>;
        \\  /**
        \\   * Output info...
        \\   */
        \\  output?: string;
        \\  /**
        \\   * Format info...
        \\   */
        \\  format?: string;
        \\}
        \\
        \\interface Input extends Entries {
        \\  /**
        \\   * Input info...
        \\   */
        \\  input: string;
        \\}
        \\
        \\interface Types extends Entries {
        \\  /**
        \\   * Types info...
        \\   */
        \\  types: string;
        \\}
        \\
        \\type EntriesOptions = Input | Types;
        \\
        \\const options: EntriesOptions[] = [
        \\  {
        \\    input: "./src/index.ts",
        \\    /*1*/output: "./dist/index.mjs",
        \\  },
        \\  {
        \\    types: "./src/types.ts",
        \\    format: "esm",
        \\  },
        \\];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "(property) Entries.output?: string", "Output info...");
}

test "TestCompletionListInObjectBindingPattern11" {
    const content =
        \\interface I {
        \\    property1: number;
        \\    property2: string;
        \\}
        \\
        \\var { property1: prop1, /**/ }: I;
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
//                 "property2",
//             },
//         },
//     });
}

test "TestImportStatementCompletions_esModuleInterop2" {
    const content =
        \\// @esModuleInterop: true
        \\// @Filename: /mod.ts
        \\const foo = 0;
        \\export = foo;
        \\// @Filename: /importExportEquals.ts
        \\[|import f/**/|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =      "foo",
//                     .InsertText = undefined("import foo$1 from \"./mod\";"),
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./mod",
//                         },
//                     },
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "foo",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

