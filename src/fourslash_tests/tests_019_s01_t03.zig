const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestAutoImportProvider_importsMap1" {
    const content =
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "module": "nodenext",
        \\    "lib": ["es5"],
        \\    "rootDir": "src",
        \\    "outDir": "dist"
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/package.json
        \\{
        \\  "type": "module",
        \\  "imports": {
        \\    "#is-browser": {
        \\      "browser": "./dist/env/browser.js",
        \\      "default": "./dist/env/node.js"
        \\    }
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/src/env/browser.ts
        \\export const isBrowser = true;
        \\// @Filename: /home/src/workspaces/project/src/env/node.ts
        \\export const isBrowser = false;
        \\// @Filename: /home/src/workspaces/project/src/a.ts
        \\isBrowser/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"#is-browser", "./env/browser.js"}, null );
}

test "TestCompletionsTypeAssertionKeywords" {
    const content =
        \\// @lib: es5
        \\const a = {
        \\  b: 42 as /*0*/
        \\};
        \\
        \\1 as /*1*/
        \\
        \\const b = 42 as /*2*/
        \\
        \\var c = </*3*/>42
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, f.Markers(), &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionTypeAssertionKeywords,
//         },
//     });
}

test "TestGoToDefinitionJsxNotSet" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /foo.jsx
        \\const /*def*/Foo = () => (
        \\    <div>foo</div>
        \\);
        \\export default Foo;
        \\// @Filename: /bar.jsx
        \\import Foo from './foo';
        \\const a = <[|/*use*/Foo|] />
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "use");
}

test "TestReferencesForClassMembers" {
    const content =
        \\class Base {
        \\    /*a1*/a: number;
        \\    /*method1*/method(): void { }
        \\}
        \\class MyClass extends Base {
        \\    /*a2*/a;
        \\    /*method2*/method() { }
        \\}
        \\
        \\var c: MyClass;
        \\c./*a3*/a;
        \\c./*method3*/method();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "a1", "a2", "a3", "method1", "method2", "method3");
}

test "TestDocCommentTemplateFunctionExpression" {
    const content =
        \\/*above*/
        \\const x = /*next*/ function f(p) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkerNames();
    // f.VerifyJSDocCompletion(undefined, marker, 7, "/**\n * \n * @param p\n */", null);
}

test "TestGetOutliningForSingleLineComments" {
    const content =
        \\[|// Single line comments at the start of the file
        \\// line 2
        \\// line 3
        \\// line 4|]
        \\module Sayings[| {
        \\
        \\    [|/*
        \\    */|]
        \\    [|// A sequence of
        \\    // single line|]
        \\    [|/*
        \\        and block
        \\    */|]
        \\    [|// comments
        \\    //|]
        \\    export class Sample[| {
        \\    }|]
        \\}|]
        \\
        \\interface IFoo[| {
        \\    [|// all consecutive single line comments should be in one block regardless of their number or empty lines/spaces inbetween
        \\
        \\    // comment 2
        \\    // comment 3
        \\
        \\    //comment 4
        \\    /// comment 5
        \\    ///// comment 6
        \\
        \\    //comment 7
        \\    ///comment 8
        \\    // comment 9
        \\    // //comment 10
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\    // // //comment 11
        \\    // comment 12
        \\    // comment 13
        \\    // comment 14
        \\    // comment 15
        \\
        \\    // comment 16
        \\    // comment 17
        \\    // comment 18
        \\    // comment 19
        \\    // comment 20    
        \\    // comment 21|]
        \\
        \\    getDist(): number; // One single line comment should not be collapsed
        \\}|]
        \\
        \\// One single line comment should not be collapsed
        \\class WithOneSingleLineComment[| {
        \\}|]
        \\
        \\function Foo()[| {
        \\   [|// comment 1
        \\     // comment 2|]
        \\    this.method = function (param)[| {
        \\    }|]
        \\
        \\   [|// comment 1
        \\     // comment 2|]
        \\    function method(param)[| {
        \\    }|]
        \\}|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOutliningSpans(undefined);
}

test "TestNodeModulesFileEditStillAllowsResolutionsToWork" {
    const content =
        \\// @Filename: /tsconfig.json
        \\{ "compilerOptions": { "module": "nodenext", "strict": true } }
        \\// @Filename: /package.json
        \\{ "type": "module", "imports": { "#foo": "./foo.cjs" } }
        \\// @Filename: /foo.cts
        \\export const x = 1;
        \\// @Filename: /index.ts
        \\import * as mod from "#foo";
        \\/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, "mod.x");
    _ = f.VerifyNoErrors(undefined);
    _ = f.VerifySuggestionDiagnostics(undefined, null);
}

test "TestFindAllRefsInsideTemplates1" {
    const content =
        \\/*1*/var /*2*/x = 10;
        \\var y = 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestQuickInfoJsDocTags8" {
    const content =
        \\// @noEmit: true
        \\// @allowJs: true
        \\// @Filename: quickInfoJsDocTags8.js
        \\/**
        \\ * @typedef {{ [x: string]: any, y: number }} Foo
        \\ */
        \\
        \\/**
        \\ * @type {(t: T) => number}
        \\ * @template {Foo} T
        \\ */
        \\const /**/foo = t => t.y;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestJsdocTypedefTagNamespace" {
    const content =
        \\// @lib: es5
        \\// @allowNonTsExtensions: true
        \\// @Filename: jsdocCompletion_typedef.js
        \\/**
        \\ * @typedef {string | number} T.NumberLike
        \\ * @typedef {{age: number}} T.People
        \\ * @typedef {string | number} T.O.Q.NumberLike
        \\ * @type {T.NumberLike}
        \\ */
        \\var x; x./*1*/;
        \\/** @type {T.O.Q.NumberLike} */
        \\var x1; x1./*2*/;
        \\/** @type {T.People} */
        \\var x1; x1./*3*/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.VerifyCompletions(undefined, &.{"1", "3"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "charAt",
//                 "toExponential",
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
//                     .Label =    "age",
//                     .SortText = undefined(string(ls.SortTextJavascriptIdentifiers)),
//                 },
//             },
//         },
//     });
}

