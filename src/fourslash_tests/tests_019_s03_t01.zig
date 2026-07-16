const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestCompletionsExportImport" {
    const content =
        \\// @lib: es5
        \\declare global {
        \\    namespace N {
        \\        const foo: number;
        \\    }
        \\}
        \\export import foo = N.foo;
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
//             .Exact = CompletionGlobalsPlus(
//                 &.{
//                     &.{
//                         .Label =  "foo",
//                         .Kind =   undefined(lsproto.CompletionItemKindVariable),
//                         .Detail = undefined("(alias) const foo: number\nimport foo = N.foo"),
//                     },
//                     &.{
//                         .Label =  "N",
//                         .Kind =   undefined(lsproto.CompletionItemKindModule),
//                         .Detail = undefined("namespace N"),
//                     },
//                 }, false,
//             ),
//         },
//     });
}

test "TestCompletionsImport_exportEquals_anonymous" {
    const content =
        \\// @noLib: true
        \\// @module: commonjs
        \\// @esModuleInterop: false
        \\// @allowSyntheticDefaultImports: false
        \\// @Filename: /src/foo-bar.ts
        \\export = 0;
        \\// @Filename: /src/b.ts
        \\exp/*0*/
        \\fooB/*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "0");
    // f.VerifyCompletions(undefined, "0", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionGlobalsPlus(
//                 &.{}, true,
//             ),
//         },
//     });
    // f.VerifyCompletions(undefined, "1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionGlobalsPlus(
//                 &.{
//                     &.{
//                         .Label = "fooBar",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "./foo-bar",
//                             },
//                         },
//                         .Detail =              undefined("(property) export=: 0"),
//                         .Kind =                undefined(lsproto.CompletionItemKindField),
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     },
//                 }, true,
//             ),
//         },
//     });
    // try f.VerifyApplyCodeActionFromCompletion(undefined, undefined("1"), &.{
//         .Name =        "fooBar",
//         .Source =      "./foo-bar",
//         .Description = "Add import from \"./foo-bar\"",
//         .NewFileContent = undefined("import fooBar = require(\"./foo-bar\")\n\nexp\nfooB"),
//     });
}

test "TestCompletionsImport_exportEqualsNamespace_noDuplicate" {
    const content =
        \\// @Filename: /node_modules/a/index.d.ts
        \\declare namespace core {
        \\    const foo: number;
        \\}
        \\declare module "a" {
        \\    export = core;
        \\}
        \\declare module "a/alias" {
        \\    export = core;
        \\}
        \\// @Filename: /user.ts
        \\import * as a from "a";
        \\/**/foo;
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
//                             .ModuleSpecifier = "a",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
}

test "TestCompletionsAfterLessThanToken" {
    const content =
        \\function f() {
        \\    const k: Record</**/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =    "string",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestReferencesForNoContext" {
    const content =
        \\namespace modTest {
        \\    //Declare
        \\    export var modVar:number;
        \\    /*1*/
        \\
        \\    //Increments
        \\    modVar++;
        \\
        \\    class testCls{
        \\        /*2*/
        \\    }
        \\
        \\    function testFn(){
        \\        //Increments
        \\        modVar++;
        \\    }  /*3*/
        \\/*4*/
        \\    namespace testMod {
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestOrganizeImports4" {
    const content =
        \\import * as something from "path";/** 
        \\ * some comment here
        \\ * and there
        \\ */
        \\import * as somethingElse from "anotherpath";
        \\import * as AnotherThing from "somepath";/** 
        \\ * some comment here
        \\ * and there
        \\ */
        \\import * as AnotherThingElse from "someotherpath";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyOrganizeImports(undefined,
//         "",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
}

test "TestRenameJsPrototypeProperty01" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\function bar() {
        \\}
        \\[|bar.prototype.[|{| "contextRangeIndex": 0 |}x|] = 10;|]
        \\var t = new bar();
        \\[|t.[|{| "contextRangeIndex": 2 |}x|] = 11;|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null , "x");
}

test "TestFormatAsyncClassMethod2" {
    const content =
        \\class Foo {
        \\    private    async     foo() {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    try f.VerifyCurrentFileContent(undefined, "class Foo {\n    private async foo() { }\n}");
}

test "TestCodeFixInferFromUsage_noCrashOnMissingParens" {
    const content =
        \\// @noImplicitAny: true
        \\// @target: esnext
        \\class C {
        \\    m() { this.x * 2; }
        \\    get x { return null; }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined);
}

test "TestJsxTagNameCompletionUnderElementClosed" {
    const content =
        \\//@Filename: file.tsx
        \\declare namespace JSX {
        \\    interface IntrinsicElements {
        \\        button: any;
        \\        div: any;
        \\    }
        \\}
        \\function fn() {
        \\    return <>
        \\        <butto/*1*/ />
        \\    </>;
        \\}
        \\function fn2() {
        \\    return <>
        \\        preceding junk <butto/*2*/ />
        \\    </>;
        \\}
        \\function fn3() {
        \\    return <>
        \\        <butto/*3*/ style="" />
        \\    </>;
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
//             .Includes = &.{
//                 &.{
//                     .Label =  "button",
//                     .Detail = undefined("(property) JSX.IntrinsicElements.button: any"),
//                 },
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
//                 &.{
//                     .Label =  "button",
//                     .Detail = undefined("(property) JSX.IntrinsicElements.button: any"),
//                 },
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
//                 &.{
//                     .Label =  "button",
//                     .Detail = undefined("(property) JSX.IntrinsicElements.button: any"),
//                 },
//             },
//         },
//     });
}

