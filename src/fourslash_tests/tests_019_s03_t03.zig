const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestJavaScriptModules12" {
    const content =
        \\// @allowJs: true
        \\// @Filename: mod1.js
        \\var x = require('fs');
        \\/*1*/
        \\// @Filename: mod2.js
        \\var y;
        \\if(true) {
        \\    y = require('fs');
        \\}
        \\/*2*/
        \\// @Filename: glob1.js
        \\var a = require;
        \\/*3*/
        \\// @Filename: glob2.js
        \\var b = '';
        \\/*4*/
        \\// @Filename: consumer.js
        \\/*5*/
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
//                 &.{
//                     .Label =    "a",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//                 &.{
//                     .Label =    "b",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//             .Excludes = &.{
//                 "y",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "y",
//                 &.{
//                     .Label =    "a",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//                 &.{
//                     .Label =    "b",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//             .Excludes = &.{
//                 "x",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "3", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "a",
//                 &.{
//                     .Label =    "b",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//             .Excludes = &.{
//                 "x",
//                 "y",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "4", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =    "a",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//                 "b",
//             },
//             .Excludes = &.{
//                 "x",
//                 "y",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"5"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =    "a",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//                 &.{
//                     .Label =    "b",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//             .Excludes = &.{
//                 "x",
//                 "y",
//             },
//         },
//     });
}

test "TestTsxGoToDefinitionUnionElementType1" {
    const content =
        \\//@Filename: file.tsx
        \\// @jsx: preserve
        \\// @noLib: true
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\    }
        \\    interface ElementAttributesProperty { props; }
        \\}
        \\function /*pt1*/SFC1(prop: { x: number }) {
        \\    return <div>hello </div>;
        \\};
        \\function SFC2(prop: { x: boolean }) {
        \\    return <h1>World </h1>;
        \\}
        \\var /*def*/SFCComp = SFC1 || SFC2;
        \\<[|SFC/*one*/Comp|] x />
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "one");
}

test "TestCompletionListInUnclosedObjectTypeLiteralInSignature03" {
    const content =
        \\interface I<TString, TNumber> {
        \\    [s: string]: TString;
        \\    [s: number]: TNumber;
        \\}
        \\
        \\declare function foo<TString, TNumber>(obj: I<TString, TNumber>): { str: TString/*1*/
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
//                 "I",
//                 "TString",
//                 "TNumber",
//             },
//             .Excludes = &.{
//                 "foo",
//                 "obj",
//             },
//         },
//     });
}

test "TestReferencesForStringLiteralPropertyNames3" {
    const content =
        \\class Foo2 {
        \\    /*1*/get "/*2*/42"() { return 0; }
        \\    /*3*/set /*4*/42(n) { }
        \\}
        \\
        \\var y: Foo2;
        \\y[/*5*/42];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5");
}

test "TestQuickInfoJsDocThisTag" {
    const content =
        \\// @strict: true
        \\// @filename: /a.ts
        \\/** @this {number} */
        \\function f/**/() {
        \\    this
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestImportNameCodeFixExistingImport3" {
    const content =
        \\[|import d, * as ns from "./module"   ;
        \\f1/*0*/();|]
        \\// @Filename: module.ts
        \\export function f1() {}
        \\export var v1 = 5;
        \\export default var d1 = 6;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import d, * as ns from \"./module\"   ;\nns.f1();",
        "import d, * as ns from \"./module\"   ;\nimport { f1 } from \"./module\";\nf1();",
    }, null );
}

test "TestCompletionListInvalidMemberNames_escapeQuote" {
    const content =
        \\declare const x: { "\"'": 0 };
        \\x[|./**/|];
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
//                     .Label =      "\"'",
//                     .InsertText = undefined("[\"\\\"'\"]"),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "\"'",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =      "\"'",
//                     .InsertText = undefined("['\"\\'']"),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "\"'",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//         .UserPreferences = &.{.QuotePreference = lsutil.QuotePreference("single")},
//     });
}

test "TestCodeFixTopLevelAwait_module_blankCompilerOptionsInTsConfig" {
    const content =
        \\// @filename: /dir/a.ts
        \\declare const p: Promise<number>;
        \\await p;
        \\export {};
        \\// @filename: /dir/tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "module": "commonjs"
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined, "fixModuleOption");
}

test "TestFindAllRefsJsDocImportTag" {
    const content =
        \\// @allowJS: true
        \\// @checkJs: true
        \\// @Filename: /b.ts
        \\export interface A { }
        \\// @Filename: /a.js
        \\/**
        \\ * @import { A } from "./b";
        \\ */
        \\
        \\/**
        \\ * @param { [|A/**/|] } a
        \\ */
        \\function f(a) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "");
}

test "TestOptionalPropertyFormatting" {
    const content =
        \\export class C extends Error {
        \\    message: string;
        \\    data? = {};
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    try f.VerifyCurrentFileContent(undefined, "export class C extends Error {\n    message: string;\n    data? = {};\n}");
}

