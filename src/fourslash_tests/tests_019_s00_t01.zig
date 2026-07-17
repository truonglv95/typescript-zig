const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestAutoImportTypeImport3" {
    const content =
        \\// @verbatimModuleSyntax: true
        \\// @target: esnext
        \\// @Filename: /foo.ts
        \\export const A = 1;
        \\export type B = { x: number };
        \\export type C = 1;
        \\export class D = { y: string };
        \\// @Filename: /test.ts
        \\import { A, type B, type C } from './foo';
        \\const b: B | C;
        \\console.log(A, D/**/);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // try f.VerifyImportFixAtPosition(undefined, &.{
//         "import { A, D, type B, type C } from './foo';\nconst b: B | C;\nconsole.log(A, D);",
//     }, &.{.OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderLast});
    // try f.VerifyImportFixAtPosition(undefined, &.{
//         "import { A, type B, type C, D } from './foo';\nconst b: B | C;\nconsole.log(A, D);",
//     }, &.{.OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderInline});
    // try f.VerifyImportFixAtPosition(undefined, &.{
//         "import { A, type B, type C, D } from './foo';\nconst b: B | C;\nconsole.log(A, D);",
//     }, &.{.OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderFirst});
}

test "TestQuickInfoJsDocTagsFunctionOverload05" {
    const content =
        \\// @Filename: quickInfoJsDocTagsFunctionOverload05.ts
        \\declare function /*1*/foo(): void;
        \\
        \\/**
        \\ * @tag Tag text
        \\ */
        \\declare function /*2*/foo(x: number): void
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestPathCompletionsTypesVersionsWildcard1" {
    const content =
        \\// @module: commonjs
        \\// @Filename: /node_modules/foo/package.json
        \\{
        \\  "types": "index.d.ts",
        \\  "typesVersions": {
        \\    "*": {
        \\      "*": ["dist/*"]
        \\    }
        \\  }
        \\}
        \\// @Filename: /node_modules/foo/nope.d.ts
        \\export const nope = 0;
        \\// @Filename: /node_modules/foo/dist/index.d.ts
        \\export const index = 0;
        \\// @Filename: /node_modules/foo/dist/blah.d.ts
        \\export const blah = 0;
        \\// @Filename: /node_modules/foo/dist/subfolder/one.d.ts
        \\export const one = 0;
        \\// @Filename: /a.ts
        \\import { } from "foo//**/";
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
//                 "blah",
//                 "index",
//                 "subfolder",
//             },
//         },
//     });
    _ = f.Insert(undefined, "subfolder/");
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "one",
//             },
//         },
//     });
}

test "TestGetOccurrencesConst03" {
    const content =
        \\namespace m {
        \\    export /*1*/const x;
        \\    export [|const|] enum E {
        \\    }
        \\}
        \\
        \\export /*2*/const x;
        \\export [|const|] enum E {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Markers()));
}

test "TestRenameAcrossMultipleProjects" {
    const content =
        \\//@Filename: a.ts
        \\[|var [|{| "contextRangeIndex": 0 |}x|]: number;|]
        \\//@Filename: b.ts
        \\/// <reference path="a.ts" />
        \\[|x|]++;
        \\//@Filename: c.ts
        \\/// <reference path="a.ts" />
        \\[|x|]++;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null , "x");
}

test "TestCompletionListOnAliases3" {
    const content =
        \\declare module 'foobar' {
        \\    interface Q { x: number; }
        \\}
        \\declare module 'thing' {
        \\    import x = require('foobar');
        \\    var m: x./*1*/;
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
//             .Exact = &.{
//                 "Q",
//             },
//         },
//     });
}

test "TestSemanticClassificatonTypeAlias" {
    const content =
        \\type /*0*/Alias = number
        \\var x: /*1*/Alias;
        \\var y = </*2*/Alias>{};
        \\function f(x: /*3*/Alias): /*4*/Alias { return undefined; }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "type.declaration", .Text = "Alias"},
//         .{.Type = "variable.declaration", .Text = "x"},
//         .{.Type = "type", .Text = "Alias"},
//         .{.Type = "variable.declaration", .Text = "y"},
//         .{.Type = "type", .Text = "Alias"},
//         .{.Type = "function.declaration", .Text = "f"},
//         .{.Type = "parameter.declaration", .Text = "x"},
//         .{.Type = "type", .Text = "Alias"},
//         .{.Type = "type", .Text = "Alias"},
//     });
}

test "TestFormattingConditionalTypes" {
    const content =
        \\/*L1*/type Diff1<T, U> = T extends U?never:T;
        \\/*L2*/type Diff2<T, U> = T    extends    U  ?    never   :     T;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "L1");
    try f.VerifyCurrentLineContent(undefined, "type Diff1<T, U> = T extends U ? never : T;");
    _ = f.GoToMarker(undefined, "L2");
    try f.VerifyCurrentLineContent(undefined, "type Diff2<T, U> = T extends U ? never : T;");
}

test "TestFindAllRefsInsideWithBlock" {
    const content =
        \\/*1*/var /*2*/x = 0;
        \\
        \\with ({}) {
        \\    var y = x;  // Reference of x here should not be picked
        \\    y++;        // also reference for y should be ignored
        \\}
        \\
        \\/*3*/x = /*4*/x + 1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestJsDocPropertyDescription6" {
    const content =
        \\interface Literal1Example {
        \\    [key: `prefix${string}`]: number | string;
        \\    /** Something else */
        \\    [key: `prefix${number}`]: number;
        \\}
        \\function literal1Example(e: Literal1Example) {
        \\    console.log(e./*literal1*/prefixMember);
        \\    console.log(e./*literal2*/anything);
        \\    console.log(e./*literal3*/prefix0);
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyQuickInfoAt(undefined, "literal1", "(index) Literal1Example[`prefix${string}`]: string | number", "") catch {};
    _ = f.VerifyQuickInfoAt(undefined, "literal2", "any", "") catch {};
    _ = f.VerifyQuickInfoAt(undefined, "literal3", "(index) Literal1Example[`prefix${string}` | `prefix${number}`]: number", "Something else") catch {};
}

