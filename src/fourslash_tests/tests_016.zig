const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestUnusedImports4FS" {
    const content =
        \\// @noUnusedLocals: true
        \\// @Filename: file2.ts
        \\[| import {Calculator, test, test2} from "./file1" |]
        \\
        \\var x = new Calculator();
        \\x.handleChar();
        \\test2();
        \\// @Filename: file1.ts
        \\export class Calculator {
        \\    handleChar() {}
        \\}
        \\
        \\export function test() {
        \\
        \\}
        \\
        \\export function test2() {
        \\
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyRangeAfterCodeFix(undefined, "import {Calculator, test2} from \"./file1\"", false, 0, 0);
}

test "TestSignatureHelpNegativeTests" {
    const content =
        \\//inside a comment foo(/*insideComment*/
        \\cl/*invalidContext*/ass InvalidSignatureHelpLocation { }
        \\InvalidSignatureHelpLocation(/*validContext*/);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyNoSignatureHelpForMarkers(undefined, "insideComment", "invalidContext", "validContext");
}

test "TestJsFileImportNoTypes2" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /default.ts
        \\export default class TestDefaultClass {}
        \\// @Filename: /defaultType.ts
        \\export default interface TestDefaultInterface {}
        \\// @Filename: /reExport/toReExport.ts
        \\export class TestClassReExport {}
        \\export interface TestInterfaceReExport {}
        \\// @Filename: /reExport/index.ts
        \\export { TestClassReExport, TestInterfaceReExport } from './toReExport';
        \\// @Filename: /exportList.ts
        \\class TestClassExportList {};
        \\interface TestInterfaceExportList {};
        \\export { TestClassExportList, TestInterfaceExportList };
        \\// @Filename: /baseline.ts
        \\export class TestClassBaseline {}
        \\export interface TestInterfaceBaseline {}
        \\// @Filename: /a.js
        \\import /**/
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
//                     .Label =      "TestClassBaseline",
//                     .InsertText = undefined("import { TestClassBaseline } from \"./baseline\";"),
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./baseline",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =      "TestClassExportList",
//                     .InsertText = undefined("import { TestClassExportList } from \"./exportList\";"),
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./exportList",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =      "TestClassReExport",
//                     .InsertText = undefined("import { TestClassReExport } from \"./reExport\";"),
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./reExport",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =      "TestDefaultClass",
//                     .InsertText = undefined("import TestDefaultClass from \"./default\";"),
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./default",
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestCompletionsGeneratorFunctions" {
    const content =
        \\function /*a*/ ;
        \\function* /*b*/ ;
        \\interface I {
        \\    abstract baseMethod(): Iterable<number>;
        \\}
        \\class C implements I {
        \\    */*c*/ ;
        \\    public */*d*/
        \\}
        \\const o: I = {
        \\    */*e*/
        \\};
        \\1 * /*f*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, &.{"a", "b"}, null);
    // f.VerifyCompletions(undefined, &.{"c", "d"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "baseMethod",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "e", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "baseMethod",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "f", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =    "Number",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestDocCommentTemplateInsideFunctionDeclaration" {
    const content =
        \\// @Filename: functionDecl.ts
        \\f/*0*/unction /*1*/foo/*2*/(/*3*/) /*4*/{ /*5*/}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.Markers();
    // try f.VerifyNoJSDocCompletion(undefined, marker);
}

test "TestFindAllRefsEnumMember" {
    const content =
        \\enum E { /*1*/A, B }
        \\const e: E./*2*/A = E./*3*/A;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestTsxCompletion4" {
    const content =
        \\//@Filename: file.tsx
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\        div: { one; two; }
        \\    }
        \\}
        \\let bag = { x: 100, y: 200 };
        \\<div {.../**/
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
//                 "bag",
//             },
//         },
//     });
}

test "TestFormatConflictMarker1" {
    const content =
        \\class C {
        \\<<<<<<< HEAD
        \\v = 1;
        \\=======
        \\v = 2;
        \\>>>>>>> Branch - a
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    try f.VerifyCurrentFileContent(undefined, "class C {\n<<<<<<< HEAD\n    v = 1;\n=======\nv = 2;\n>>>>>>> Branch - a\n}");
}

test "TestCompletionListOnAliasedModule" {
    const content =
        \\namespace M {
        \\    export namespace N {
        \\        export function foo() { }
        \\        function bar() { }
        \\    }
        \\}
        \\import p = M.N;
        \\p./**/
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
//                 "foo",
//             },
//         },
//     });
}

test "TestGetPreProcessedFile" {
    const content =
        \\// @moduleResolution: classic
        \\// @Filename: refFile1.ts
        \\class D { }
        \\// @Filename: refFile2.ts
        \\export class E {}
        \\// @Filename: main.ts
        \\// @ResolveReference: true
        \\///<reference path="refFile1.ts" />
        \\///<reference path = "/*1*/NotExistRef.ts/*2*/" />
        \\/*3*////<reference path "invalidRefFile1.ts" />/*4*/
        \\import ref2 = require("refFile2");
        \\import noExistref2 = require(/*5*/"NotExistRefFile2"/*6*/);
        \\import invalidRef1  /*7*/require/*8*/("refFile2");
        \\import invalidRef2 = /*9*/requi/*10*/(/*10A*/"refFile2");
        \\var obj: /*11*/C/*12*/;
        \\var obj1: D;
        \\var obj2: ref2.E;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "main.ts");
    try f.VerifyNumberOfErrorsInCurrentFile(undefined, 7);
    try f.VerifyErrorExistsBetweenMarkers(undefined, "1", "2");
    try f.VerifyErrorExistsBetweenMarkers(undefined, "3", "4");
    try f.VerifyErrorExistsBetweenMarkers(undefined, "5", "6");
    try f.VerifyErrorExistsBetweenMarkers(undefined, "7", "8");
    try f.VerifyErrorExistsBetweenMarkers(undefined, "9", "10");
    try f.VerifyErrorExistsBetweenMarkers(undefined, "10", "10A");
    try f.VerifyErrorExistsBetweenMarkers(undefined, "11", "12");
}

test "TestNavigationBarItemsClass5" {
    const content =
        \\class Foo {}
        \\let Foo = 1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestSmartIndentNamedImport" {
    const content =
        \\import {/*0*/
        \\    numbers as bn,/*1*/
        \\    list/*2*/
        \\} from '@bykov/basics';/*3*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "0");
    try f.VerifyCurrentLineContent(undefined, "import {");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCurrentLineContent(undefined, "    numbers as bn,");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyCurrentLineContent(undefined, "    list");
    _ = f.GoToMarker(undefined, "3");
    try f.VerifyCurrentLineContent(undefined, "} from '@bykov/basics';");
}

test "TestCodeFixClassImplementInterface_quotePreferenceDouble" {
    const content =
        \\interface I {
        \\    a(): void;
        \\    b(x: "x", y: "a" | "b"): "b";
        \\
        \\    c: "c";
        \\    d: { e: "e"; };
        \\}
        \\class Foo implements I {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFix(undefined, .{
//         .Description = "Implement interface 'I'",
//         .NewFileContent = "interface I {\n    a(): void;\n    b(x: \"x\", y: \"a\" | \"b\"): \"b\";\n\n    c: \"c\";\n    d: { e: \"e\"; };\n}\nclass Foo implements I {\n    a(): void {\n        throw new Error(\"Method not implemented.\");\n    }\n    b(x: \"x\", y: \"a\" | \"b\"): \"b\" {\n        throw new Error(\"Method not implemented.\");\n    }\n    c: \"c\";\n    d: { e: \"e\"; };\n}",
//         .Index =           0,
//         .UserPreferences = &.{.QuotePreference = lsutil.QuotePreference("double")},
//     });
}

test "TestAutoImportTypeImport1" {
    const content =
        \\// @verbatimModuleSyntax: true
        \\// @target: esnext
        \\// @Filename: /foo.ts
        \\export const A = 1;
        \\export type B = { x: number };
        \\export type C = 1;
        \\export class D = { y: string };
        \\// @Filename: /test.ts
        \\import { A, D, type C } from './foo';
        \\const b: B/**/ | C;
        \\console.log(A, D);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // try f.VerifyImportFixAtPosition(undefined, &.{
//         "import { A, D, type C, type B } from './foo';\nconst b: B | C;\nconsole.log(A, D);",
//     }, &.{.OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderInline});
    // try f.VerifyImportFixAtPosition(undefined, &.{
//         "import { A, D, type B, type C } from './foo';\nconst b: B | C;\nconsole.log(A, D);",
//     }, &.{.OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderLast});
    // try f.VerifyImportFixAtPosition(undefined, &.{
//         "import { A, D, type C, type B } from './foo';\nconst b: B | C;\nconsole.log(A, D);",
//     }, &.{.OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderFirst});
}

test "TestCallHierarchyFunctionAmbiguity1" {
    const content =
        \\// @filename: a.d.ts
        \\declare function foo(x?: number): void;
        \\// @filename: b.d.ts
        \\declare function foo(x?: string): void;
        \\declare function foo(x?: boolean): void;
        \\// @filename: main.ts
        \\function bar() {
        \\    /**/foo();
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // try f.VerifyBaselineCallHierarchy(undefined);
}

test "TestGetOccurrencesTryCatchFinally2" {
    const content =
        \\try {
        \\    [|t/*1*/r/*2*/y|] {
        \\    }
        \\    [|c/*3*/atch|] (x) {
        \\    }
        \\
        \\    try {
        \\    }
        \\    finally {
        \\    }
        \\}
        \\catch (e) {
        \\}
        \\finally {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Markers()));
}

test "TestCompletionListInUnclosedForLoop01" {
    const content =
        \\for (let i = 0; /*1*/
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
//                 "i",
//             },
//         },
//     });
}

test "TestSymbolNameAtUnparseableFunctionOverload" {
    const content =
        \\class TestClass {
        \\    public function foo(x: string): void;
        \\    public function foo(): void;
        \\    foo(x: any): void {
        \\        this.bar(/**/x); // should not error
        \\    }
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyQuickInfoExists(undefined);
}

test "TestJsdocExtendsTagCompletion" {
    const content =
        \\// @lib: es5
        \\/** @extends {/**/} */
        \\class A {}
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
//             .Exact = CompletionGlobalTypesPlus(
//                 &.{
//                     "A",
//                 },
//             ),
//         },
//     });
}

test "TestQuickInfoDisplayPartsTypeParameterInInterface" {
    const content =
        \\interface /*1*/I</*2*/T> {
        \\    new </*3*/U>(/*4*/a: /*5*/U, /*6*/b: /*7*/T): /*8*/U;
        \\    </*9*/U>(/*10*/a: /*11*/U, /*12*/b: /*13*/T): /*14*/U;
        \\    /*15*/method</*16*/U>(/*17*/a: /*18*/U, /*19*/b: /*20*/T): /*21*/U;
        \\}
        \\var /*22*/iVal: /*23*/I<string>;
        \\new /*24*/iVal("hello", "hello");
        \\/*25*/iVal("hello", "hello");
        \\/*26*/iVal./*27*/method("hello", "hello");
        \\interface /*28*/I1</*29*/T extends /*30*/I<string>> {
        \\    new </*31*/U extends /*32*/I<string>>(/*33*/a: /*34*/U, /*35*/b: /*36*/T): /*37*/U;
        \\    </*38*/U extends /*39*/I<string>>(/*40*/a: /*41*/U, /*42*/b: /*43*/T): /*44*/U;
        \\    /*45*/method</*46*/U extends /*47*/I<string>>(/*48*/a: /*49*/U, /*50*/b: /*51*/T): /*52*/U;
        \\}
        \\var /*53*/iVal1: /*54*/I1</*55*/I<string>>;
        \\new /*56*/iVal1(/*57*/iVal, /*58*/iVal);
        \\/*59*/iVal1(/*60*/iVal, /*61*/iVal);
        \\/*62*/iVal1./*63*/method(/*64*/iVal, /*65*/iVal);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestGoToImplementationInterfaceMethod_09" {
    const content =
        \\interface Foo {
        \\    hello (): void;
        \\}
        \\
        \\class SubBar extends Bar {
        \\    hello() {}
        \\}
        \\
        \\class Bar extends SuperBar {
        \\    hello() {}
        \\
        \\    whatever() {
        \\        super.he/*function_call*/llo();
        \\        super["hel/*element_access*/lo"]();
        \\    }
        \\}
        \\
        \\class SuperBar extends MegaBar {
        \\    [|hello|]() {}
        \\}
        \\
        \\class MegaBar implements Foo {
        \\    hello() {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "function_call", "element_access");
}

test "TestGoToDefinitionExternalModuleName8" {
    const content =
        \\// @Filename: b.ts
        \\export {Foo, Bar} from [|'e/*1*/'|];
        \\// @Filename: a.ts
        \\declare module /*2*/"e" {
        \\    class Foo { }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestImportNameCodeFix_commonjs_allowSynthetic" {
    const content =
        \\// @module: esnext
        \\// @moduleResolution: bundler
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @allowSyntheticDefaultImports: true
        \\// @Filename: /test_module.js
        \\const MY_EXPORTS = {}
        \\module.exports = MY_EXPORTS;
        \\// @Filename: /index.js
        \\const newVar = {
        \\  any: MY_EXPORTS/**/,
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "const MY_EXPORTS = require(\"./test_module\");\n\nconst newVar = {\n  any: MY_EXPORTS,\n}",
    }, null );
}

test "TestFormatAfterObjectLiteral" {
    const content =
        \\/**/namespace Default{var x= ( { } ) ;}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "");
    try f.VerifyCurrentLineContent(undefined, "namespace Default { var x = ({}); }");
}

test "TestQuickInfoDisplayPartsClassAutoAccessors" {
    const content =
        \\class c {
        \\    public accessor /*1a*/publicProperty: string;
        \\    private accessor /*2a*/privateProperty: string;
        \\    protected accessor /*3a*/protectedProperty: string;
        \\    static accessor /*4a*/staticProperty: string;
        \\    private static accessor /*5a*/privateStaticProperty: string;
        \\    protected static accessor /*6a*/protectedStaticProperty: string;
        \\    method() {
        \\        var x: string;
        \\        x = this./*1g*/publicProperty;
        \\        x = this./*2g*/privateProperty;
        \\        x = this./*3g*/protectedProperty;
        \\        x = c./*4g*/staticProperty;
        \\        x = c./*5g*/privateStaticProperty;
        \\        x = c./*6g*/protectedStaticProperty;
        \\        this./*1s*/publicProperty = "";
        \\        this./*2s*/privateProperty = "";
        \\        this./*3s*/protectedProperty = "";
        \\        c./*4s*/staticProperty = "";
        \\        c./*5s*/privateStaticProperty = "";
        \\        c./*6s*/protectedStaticProperty = "";
        \\    }
        \\}
        \\var cInstance = new c();
        \\var y: string;
        \\y = /*7g*/cInstance./*8g*/publicProperty;
        \\y = /*9g*/c./*10g*/staticProperty;
        \\/*7s*/cInstance./*8s*/publicProperty = y;
        \\/*9s*/c./*10s*/staticProperty = y;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestNavigationBarItemsItemsExternalModules2" {
    const content =
        \\// @Filename: test/file.ts
        \\export class Bar {
        \\    public s: string;
        \\}
        \\export var x: number;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestInlayHintsImportType2" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: /a.js
        \\module.exports.a = 1
        \\// @Filename: /b.js
        \\function foo () { return require('./a'); }
        \\function bar () { return require('./a').a; }
        \\const c = foo()
        \\const d = bar()
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/b.js");
    // try f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayVariableTypeHints = core.TSTrue, .IncludeInlayFunctionLikeReturnTypeHints = core.TSTrue}});
}

test "TestCallHierarchyFunctionAmbiguity5" {
    const content =
        \\// @filename: a.d.ts
        \\declare function foo(x?: number): void;
        \\// @filename: b.d.ts
        \\declare function foo(x?: string): void;
        \\declare function foo(x?: boolean): void;
        \\// @filename: main.ts
        \\function /**/bar() {
        \\    foo();
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // try f.VerifyBaselineCallHierarchy(undefined);
}

test "TestPathCompletionsTypesVersionsWildcard2" {
    const content =
        \\// @module: commonjs
        \\// @resolveJsonModule: false
        \\// @Filename: /node_modules/foo/package.json
        \\{
        \\  "types": "index.d.ts",
        \\  "typesVersions": {
        \\    "<=3.4.1": {
        \\      "*": ["ts-old/*"]
        \\    }
        \\  }
        \\}
        \\// @Filename: /node_modules/foo/nope.d.ts
        \\export const nope = 0;
        \\// @Filename: /node_modules/foo/ts-old/index.d.ts
        \\export const index = 0;
        \\// @Filename: /node_modules/foo/ts-old/blah.d.ts
        \\export const blah = 0;
        \\// @Filename: /node_modules/foo/ts-old/subfolder/one.d.ts
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
//                 "nope",
//                 "ts-old",
//             },
//         },
//     });
}

test "TestQuickInfoDisplayPartsVar" {
    const content =
        \\var /*1*/a = 10;
        \\function foo() {
        \\    var /*2*/b = /*3*/a;
        \\}
        \\namespace m {
        \\    var /*4*/c = 10;
        \\    export var /*5*/d = 10;
        \\}
        \\var /*6*/f: () => number;
        \\var /*7*/g = /*8*/f;
        \\/*9*/f();
        \\var /*10*/h: { (a: string): number; (a: number): string; };
        \\var /*11*/i = /*12*/h;
        \\/*13*/h(10);
        \\/*14*/h("hello");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestSmartSelection_simple1" {
    const content =
        \\class Foo {
        \\  bar(a, b) {
        \\      if (/*1*/a === b) {
        \\          return tr/*2*/ue;
        \\      }
        \\      return false;
        \\  }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSelectionRanges(undefined);
}

test "TestJsdocCallbackTag" {
    const content =
        \\// @lib: es5
        \\// @strict: false
        \\// @allowNonTsExtensions: true
        \\// @Filename: jsdocCallbackTag.js
        \\/**
        \\ * @callback FooHandler - A kind of magic
        \\ * @param {string} eventName - So many words
        \\ * @param eventName2 {number | string} - Silence is golden
        \\ * @param eventName3 - Osterreich mos def
        \\ * @return {number} - DIVEKICK
        \\ */
        \\/**
        \\ * @type {FooHa/*8*/ndler} callback
        \\ */
        \\var t/*1*/;
        \\
        \\/**
        \\ * @callback FooHandler2 - What, another one?
        \\ * @param {string=} eventName - it keeps happening
        \\ * @param {string} [eventName2] - i WARNED you dog
        \\ */
        \\/**
        \\ * @type {FooH/*3*/andler2} callback
        \\ */
        \\var t2/*2*/;
        \\t(/*4*/"!", /*5*/12, /*6*/false);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyQuickInfoIs(undefined, "var t: FooHandler", "");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyQuickInfoIs(undefined, "var t2: FooHandler2", "");
    _ = f.GoToMarker(undefined, "3");
    try f.VerifyQuickInfoIs(undefined, "type FooHandler2 = (eventName?: string | undefined, eventName2?: string) => any", "- What, another one?");
    _ = f.GoToMarker(undefined, "8");
    try f.VerifyQuickInfoIs(undefined, "type FooHandler = (eventName: string, eventName2: number | string, eventName3: any) => number", "- A kind of magic");
}

test "TestCompletionListObjectMembers" {
    const content =
        \\ var object: {
        \\     (bar: any): any;
        \\     new (bar: any): any;
        \\     [bar: any]: any;
        \\     bar: any;
        \\     foo(bar: any): any;
        \\ };
        \\object./**/
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
//                     .Label =  "bar",
//                     .Detail = undefined("(property) bar: any"),
//                 },
//                 &.{
//                     .Label =  "foo",
//                     .Detail = undefined("(method) foo(bar: any): any"),
//                 },
//             },
//         },
//     });
}

test "TestCompletionListInUnclosedTemplate01" {
    const content =
        \\var x;
        \\var y = (p) => 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "p",
//                 "x",
//             },
//         },
//     });
}

test "TestCompletionsECMAPrivateMemberTriggerCharacter" {
    const content =
        \\// @target: esnext
        \\class K {
        \\  #value: number;
        \\
        \\  foo() {
        \\     this.#/**/
        \\  }
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
//                 "#value",
//                 "foo",
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
//                 "#value",
//                 "foo",
//             },
//         },
//     });
}

test "TestDocumentHighlights_moduleImport_filesToSearchWithInvalidFile" {
    const content =
        \\// @Filename: /node_modules/@types/foo/index.d.ts
        \\export const x: number;
        \\// @Filename: /a.ts
        \\import * as foo from "foo";
        \\foo.[|x|];
        \\// @Filename: /b.ts
        \\import { [|x|] } from "foo";
        \\// @Filename: /c.ts
        \\import { x } from "foo";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlightsWithOptions(undefined, null , &.{"/a.ts", "/b.ts", "/unknown.ts"}, ToAny(f.Ranges()));
}

test "TestThisPredicateFunctionQuickInfo" {
    const content =
        \\class RoyalGuard {
        \\    isLeader(): this is LeadGuard {
        \\        return this instanceof LeadGuard;
        \\    }
        \\    isFollower(): this is FollowerGuard {
        \\        return this instanceof FollowerGuard;
        \\    }
        \\}
        \\
        \\class LeadGuard extends RoyalGuard {
        \\    lead(): void {};
        \\}
        \\
        \\class FollowerGuard extends RoyalGuard {
        \\    follow(): void {};
        \\}
        \\
        \\let a: RoyalGuard = new FollowerGuard();
        \\if (a.is/*1*/Leader()) {
        \\    a./*2*/;
        \\}
        \\else if (a.is/*3*/Follower()) {
        \\    a./*4*/;
        \\}
        \\
        \\interface GuardInterface {
        \\   isLeader(): this is LeadGuard;
        \\   isFollower(): this is FollowerGuard;
        \\}
        \\
        \\let b: GuardInterface;
        \\if (b.is/*5*/Leader()) {
        \\    b./*6*/;
        \\}
        \\else if (b.is/*7*/Follower()) {
        \\    b./*8*/;
        \\}
        \\
        \\if (((a.isLeader)())) {
        \\    a./*9*/;
        \\}
        \\else if (((a).isFollower())) {
        \\    a./*10*/;
        \\}
        \\
        \\if (((a["isLeader"])())) {
        \\    a./*11*/;
        \\}
        \\else if (((a)["isFollower"]())) {
        \\    a./*12*/;
        \\}
        \\
        \\let leader/*13*/Status = a.isLeader();
        \\function isLeaderGuard(g: RoyalGuard) {
        \\   return g.isLeader();
        \\}
        \\let checked/*14*/LeaderStatus = isLeader/*15*/Guard(a);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "(method) RoyalGuard.isLeader(): this is LeadGuard", "");
    try f.VerifyQuickInfoAt(undefined, "3", "(method) RoyalGuard.isFollower(): this is FollowerGuard", "");
    try f.VerifyQuickInfoAt(undefined, "5", "(method) GuardInterface.isLeader(): this is LeadGuard", "");
    try f.VerifyQuickInfoAt(undefined, "7", "(method) GuardInterface.isFollower(): this is FollowerGuard", "");
    try f.VerifyQuickInfoAt(undefined, "13", "let leaderStatus: boolean", "");
    try f.VerifyQuickInfoAt(undefined, "14", "let checkedLeaderStatus: boolean", "");
    try f.VerifyQuickInfoAt(undefined, "15", "function isLeaderGuard(g: RoyalGuard): g is LeadGuard", "");
}

test "TestAutoImportPackageJsonImportsConditions" {
    const content =
        \\// @module: node18
        \\// @Filename: /package.json
        \\{
        \\  "imports": {
        \\    "#thing": {
        \\        "types": { "import": "./types-esm/thing.d.mts", "require": "./types/thing.d.ts" },
        \\        "default": { "import": "./esm/thing.mjs", "require": "./dist/thing.js" }
        \\     }
        \\  }
        \\}
        \\// @Filename: /src/.ts
        \\something/*a*/
        \\// @Filename: /types/thing.d.ts
        \\export function something(name: string): any;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyImportFixModuleSpecifiers(undefined, "a", &.{"#thing"}, null );
}

test "TestJsxAttributeSnippetCompletionAfterTypeArgs" {
    const content =
        \\// @strict: false
        \\//@Filename: file.tsx
        \\declare const React: any;
        \\
        \\namespace JSX {
        \\    export interface IntrinsicElements {
        \\        div: any;
        \\    }
        \\}
        \\
        \\function GenericElement<T>(props: {xyz?: T}) {
        \\    return <></>
        \\}
        \\
        \\function fn1() {
        \\    return <div>
        \\        <GenericElement<number> /*1*/ />
        \\    </div>
        \\}
        \\
        \\function fn2() {
        \\    return <>
        \\        <GenericElement<number> /*2*/ />
        \\    </>
        \\}
        \\function fn3() {
        \\    return <div>
        \\        <GenericElement<number> /*3*/ ></GenericElement>
        \\    </div>
        \\}
        \\
        \\function fn4() {
        \\    return <>
        \\        <GenericElement<number> /*4*/ ></GenericElement>
        \\    </>
        \\}
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
//             .Includes = &.{
//                 &.{
//                     .Label =            "xyz?",
//                     .InsertText =       undefined("xyz={$1}"),
//                     .FilterText =       undefined("xyz"),
//                     .Detail =           undefined("(property) xyz?: number"),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                     .SortText =         undefined(string(ls.SortTextOptionalMember)),
//                 },
//             },
//         },
//     });
}

test "TestCompletionListInObjectBindingPattern06" {
    const content =
        \\interface I {
        \\    property1: number;
        \\    property2: string;
        \\}
        \\
        \\var foo: I;
        \\var { property1, property2, /**/ } = foo;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, "", null);
}

test "TestCompletionListInClosedObjectTypeLiteralInSignature04" {
    const content =
        \\interface I<TString, TNumber> {
        \\    [s: string]: TString;
        \\    [s: number]: TNumber;
        \\}
        \\
        \\declare function foo<TString, TNumber>(obj: I<TString, TNumber>): { /*1*/ }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =    "readonly",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestQuickInfoCallProperty" {
    const content =
        \\interface I {
        \\    /** Doc */
        \\    m: () => void;
        \\}
        \\function f(x: I): void {
        \\    x./**/m();
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "(property) I.m: () => void", "Doc");
}

test "TestRenameReferenceFromLinkTag5" {
    const content =
        \\enum E {
        \\    /** {@link E./**/A} */
        \\    A
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, null , "");
}

test "TestCompletionListAfterInvalidCharacter" {
    const content =
        \\// Completion after invalid character
        \\namespace testModule {
        \\    export var foo = 1;
        \\}
        \\@
        \\testModule./**/
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
//                 "foo",
//             },
//         },
//     });
}

test "TestUnusedClassInNamespace4" {
    const content =
        \\// @strict: false
        \\// @noUnusedLocals: true
        \\// @noUnusedParameters:true
        \\ [| namespace Validation {
        \\    class c1 {
        \\
        \\    }
        \\
        \\    export class c2 {
        \\
        \\    }
        \\
        \\    class c3 {
        \\        public x: c1;
        \\    }
        \\} |]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyRangeAfterCodeFix(undefined, "namespace Validation {\n    class c1 {\n\n    }\n\n    export class c2 {\n\n    }\n}", false, 0, 0);
}

test "TestSignatureHelpInFunctionCall" {
    const content =
        \\var items = [];
        \\items.forEach(item => {
        \\    for (/**/
        \\});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyNoSignatureHelpForMarkers(undefined, "");
}

test "TestNavigationBarItemsFunctionsBroken" {
    const content =
        \\function f() {
        \\    function;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestGetJavaScriptQuickInfo2" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: Foo.js
        \\/** @param {number} [a] */
        \\function /**/f(a) { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "function f(a?: number): void", "");
}

test "TestCodeFixMissingTypeAnnotationOnExports7" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\function foo(): number[] { return [42]; }
        \\export const c = { foo: foo() };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Add annotation of type '{ foo: number[]; }'",
        .NewFileContent = "function foo(): number[] { return [42]; }\nexport const c: {\n    foo: number[];\n} = { foo: foo() };",
        .Index = 0,
    });
}

test "TestFormattingOnOpenBraceOfFunctions" {
    const content =
        \\/**/function T2_y()
        \\{
        \\Plugin.T1.t1_x();
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "");
    try f.VerifyCurrentLineContent(undefined, "function T2_y() {");
}

test "TestSignatureHelpExpandedRestUnlabeledTuples" {
    const content =
        \\export function complex(item: string, another: string, ...rest: [] | [object, (err: Error) => void] | [(err: Error) => void, ...object[]]) {
        \\    
        \\}
        \\
        \\complex(/*1*/);
        \\complex("ok", "ok", /*2*/);
        \\complex("ok", "ok", e => void e, {}, /*3*/);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // try f.VerifySignatureHelp(undefined, .{.Text = "complex(item: string, another: string): void", .ParameterCount = 2, .ParameterName = "item", .ParameterSpan = "item: string", .OverloadsCount = 3, .IsVariadic = false, .IsVariadicSet = true});
    _ = f.GoToMarker(undefined, "2");
    // try f.VerifySignatureHelp(undefined, .{.Text = "complex(item: string, another: string, rest_0: object, rest_1: (err: Error) => void): void", .ParameterCount = 4, .ParameterName = "rest_0", .ParameterSpan = "rest_0: object", .OverloadsCount = 3, .IsVariadic = false, .IsVariadicSet = true});
    _ = f.GoToMarker(undefined, "3");
    // try f.VerifySignatureHelp(undefined, .{.Text = "complex(item: string, another: string, rest_0: (err: Error) => void, ...rest: object[]): void", .OverloadsCount = 3, .IsVariadic = true, .IsVariadicSet = true});
}

test "TestCompletionListInUnclosedFunction06" {
    const content =
        \\function foo(x: string, y: number, z: boolean) {
        \\    function bar(a: number, b: string = /*1*/, c: typeof x = "hello"
        \\
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
//                 "foo",
//                 "x",
//                 "y",
//                 "z",
//                 "bar",
//                 "a",
//             },
//         },
//     });
}

test "TestGetOutliningSpansForUnbalancedEndRegion" {
    const content =
        \\// bottom-heavy region balance
        \\[|// #region matched
        \\
        \\// #endregion matched|]
        \\
        \\// #endregion unmatched
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyOutliningSpans(undefined, lsproto.FoldingRangeKindRegion);
}

test "TestSignatureHelpTypeArguments" {
    const content =
        \\declare function f(a: number, b: string, c: boolean): void; // ignored, not generic
        \\declare function f<T extends number>(): void;
        \\declare function f<T, U>(): void;
        \\declare function f<T, U, V extends string>(): void;
        \\f</*f0*/;
        \\f<number, /*f1*/;
        \\f<number, string, /*f2*/;
        \\
        \\declare const C: {
        \\    new<T extends number>(): void;
        \\    new<T, U>(): void;
        \\    new<T, U, V extends string>(): void;
        \\};
        \\new C</*C0*/;
        \\new C<number, /*C1*/;
        \\new C<number, string, /*C2*/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "f0");
    // try f.VerifySignatureHelp(undefined, .{.Text = "f<T extends number>(): void", .ParameterName = "T", .ParameterSpan = "T extends number", .OverloadsCount = 3});
    _ = f.GoToMarker(undefined, "f1");
    // try f.VerifySignatureHelp(undefined, .{.Text = "f<T, U>(): void", .ParameterName = "U", .ParameterSpan = "U", .OverloadsCount = 2});
    _ = f.GoToMarker(undefined, "f2");
    // try f.VerifySignatureHelp(undefined, .{.Text = "f<T, U, V extends string>(): void", .ParameterName = "V", .ParameterSpan = "V extends string"});
    _ = f.GoToMarker(undefined, "C0");
    // try f.VerifySignatureHelp(undefined, .{.Text = "C<T extends number>(): void", .ParameterName = "T", .ParameterSpan = "T extends number", .OverloadsCount = 3});
    _ = f.GoToMarker(undefined, "C1");
    // try f.VerifySignatureHelp(undefined, .{.Text = "C<T, U>(): void", .ParameterName = "U", .ParameterSpan = "U", .OverloadsCount = 2});
    _ = f.GoToMarker(undefined, "C2");
    // try f.VerifySignatureHelp(undefined, .{.Text = "C<T, U, V extends string>(): void", .ParameterName = "V", .ParameterSpan = "V extends string"});
}

test "TestCodeFixClassImplementInterfaceClassExpression" {
    const content =
        \\interface I { x: number; }
        \\new class implements I {};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'I'",
        .NewFileContent = "interface I { x: number; }\nnew class implements I {\n    x: number;\n};",
        .Index = 0,
    });
}

test "TestQuickInfoDisplayPartsClassMethod" {
    const content =
        \\class c {
        \\    public /*1*/publicMethod() { }
        \\    private /*2*/privateMethod() { }
        \\    protected /*21*/protectedMethod() { }
        \\    static /*3*/staticMethod() { }
        \\    private static /*4*/privateStaticMethod() { }
        \\    protected static /*41*/protectedStaticMethod() { }
        \\    method() {
        \\        this./*5*/publicMethod();
        \\        this./*6*/privateMethod();
        \\        this./*61*/protectedMethod();
        \\        c./*7*/staticMethod();
        \\        c./*8*/privateStaticMethod();
        \\        c./*81*/protectedStaticMethod();
        \\    }
        \\}
        \\var cInstance = new c();
        \\/*9*/cInstance./*10*/publicMethod();
        \\/*11*/c./*12*/staticMethod();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestGoToImplementationInterfaceMethod_08" {
    const content =
        \\interface Foo {
        \\    hello (): void;
        \\}
        \\
        \\class SuperBar implements Foo {
        \\   [|hello|]() {}
        \\}
        \\
        \\class Bar extends SuperBar {
        \\   whatever() { this.he/*function_call*/llo(); }
        \\}
        \\
        \\class SubBar extends Bar {
        \\   [|hello|]() {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "function_call");
}

test "TestImportCompletionsPackageJsonImportsConditions1" {
    const content =
        \\// @module: node18
        \\// @Filename: /package.json
        \\{
        \\  "imports": {
        \\    "#thing": {
        \\        "types": { "import": "./types-esm/thing.d.mts", "require": "./types/thing.d.ts" },
        \\        "default": { "import": "./esm/thing.mjs", "require": "./dist/thing.js" }
        \\     }
        \\  }
        \\}
        \\// @Filename: /types/thing.d.ts
        \\export function something(name: string): any;
        \\// @Filename: /src/foo.ts
        \\import {} from "/*1*/";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"1"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "#thing",
//             },
//         },
//     });
}

test "TestInlayHintsFunctionParameterTypes1" {
    const content =
        \\type F1 = (a: string, b: number) => void
        \\const f1: F1 = (a, b) => { }
        \\const f2: F1 = (a, b: number) => { }
        \\function foo1 (cb: (a: string) => void) {}
        \\foo1((a) => { })
        \\function foo2 (cb: (a: Exclude<1 | 2 | 3, 1>) => void) {}
        \\foo2((a) => { })
        \\function foo3 (a: (b: (c: (d: Exclude<1 | 2 | 3, 1>) => void) => void) => void) {}
        \\foo3(a => {
        \\    a(d => {})
        \\})
        \\function foo4<T>(v: T, a: (v: T) => void) {}
        \\foo4(1, a => { })
        \\type F2 = (a: {
        \\    a: number
        \\    b: string
        \\}) => void
        \\const foo5: F2 = (a) => { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayFunctionParameterTypeHints = core.TSTrue}});
}

test "TestGetOccurrencesPrivate1" {
    const content =
        \\namespace m {
        \\    export class C1 {
        \\        public pub1;
        \\        public pub2;
        \\        [|private|] priv1;
        \\        [|private|] priv2;
        \\        protected prot1;
        \\        protected prot2;
        \\
        \\        public public;
        \\        [|private|] private;
        \\        protected protected;
        \\
        \\        public constructor(public a, [|private|] b, protected c, public d, [|private|] e, protected f) {
        \\            this.public = 10;
        \\            this.private = 10;
        \\            this.protected = 10;
        \\        }
        \\
        \\        public get x() { return 10; }
        \\        public set x(value) { }
        \\
        \\        public static statPub;
        \\        [|private|] static statPriv;
        \\        protected static statProt;
        \\    }
        \\
        \\    export interface I1 {
        \\    }
        \\
        \\    export declare namespace ma.m1.m2.m3 {
        \\        interface I2 {
        \\        }
        \\    }
        \\
        \\    export namespace mb.m1.m2.m3 {
        \\        declare var foo;
        \\
        \\        export class C2 {
        \\            public pub1;
        \\            private priv1;
        \\            protected prot1;
        \\
        \\            protected constructor(public public, protected protected, private private) {
        \\                public = private = protected;
        \\            }
        \\        }
        \\    }
        \\
        \\    declare var ambientThing: number;
        \\    export var exportedThing = 10;
        \\    declare function foo(): string;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestCompletionListInClassStaticBlocks" {
    const content =
        \\// @lib: es5
        \\// @target: esnext
        \\class Foo {
        \\    static #a = 1;
        \\    static a() {
        \\        this./*1*/
        \\    }
        \\    static b() {
        \\        Foo./*2*/
        \\    }
        \\    static {
        \\        this./*3*/
        \\    }
        \\    static {
        \\        Foo./*4*/
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"1", "2", "3", "4"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionFunctionMembersPlus(
//                 &.{
//                     &.{
//                         .Label =    "#a",
//                         .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                     },
//                     &.{
//                         .Label =    "a",
//                         .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                     },
//                     &.{
//                         .Label =    "b",
//                         .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                     },
//                     &.{
//                         .Label = "prototype",
//                     },
//                 },
//             ),
//         },
//     });
}

test "TestGenericObjectBaseType" {
    const content =
        \\// @strict: false
        \\class C<T> {
        \\    constructor(){}
        \\    foo(a: T) {
        \\        return a.toString();
        \\    }
        \\}
        \\var x = new C<string>();
        \\var y: string = x.foo("hi");
        \\/*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyNoErrors(undefined);
}

test "TestQuickInfoOnConstructorWithGenericParameter" {
    const content =
        \\interface I {
        \\    x: number;
        \\}
        \\class Foo<T> {
        \\    y: T;
        \\}
        \\class A {
        \\    foo() { }
        \\}
        \\class B extends A {
        \\    constructor(a: Foo<I>, b: number) {
        \\        super();
        \\    }
        \\}
        \\var x = new /*2*/B(/*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // try f.VerifySignatureHelp(undefined, .{.Text = "B(a: Foo<I>, b: number): B"});
    _ = f.Insert(undefined, "null,");
    // try f.VerifySignatureHelp(undefined, .{.Text = "B(a: Foo<I>, b: number): B"});
    _ = f.Insert(undefined, "10);");
    try f.VerifyQuickInfoAt(undefined, "2", "constructor B(a: Foo<I>, b: number): B", "");
}

test "TestNavigationBarAnonymousClassAndFunctionExpressions2" {
    const content =
        \\console.log(console.log(class Y {}, class X {}), console.log(class B {}, class A {}));
        \\console.log(class Cls { meth() {} });
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestGoToImplementationInterfaceMethod_05" {
    const content =
        \\interface Foo {
        \\    hello (): void;
        \\}
        \\
        \\class SuperBar implements Foo {
        \\    [|hello|]() {}
        \\}
        \\
        \\class Bar extends SuperBar {
        \\    hello2() {}
        \\}
        \\
        \\class OtherBar extends SuperBar {
        \\    hello() {}
        \\    hello2() {}
        \\    hello3() {}
        \\}
        \\
        \\class NotRelatedToBar {
        \\    hello() {}         // Equivalent to last case, but shares no common ancestors with Bar and so is not returned
        \\    hello2() {}
        \\    hello3() {}
        \\}
        \\
        \\class NotBar extends SuperBar {
        \\    hello() {}         // Should not be returned because it is not structurally equivalent to Bar
        \\}
        \\
        \\function whatever(x: Bar) {
        \\    x.he/*function_call*/llo()
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "function_call");
}

test "TestCompletionListStringParenthesizedType" {
    const content =
        \\type T1 = "a" | "b" | "c";
        \\type T2<T extends T1> = {};
        \\
        \\type T3 = T2<"[|/*1*/|]">;
        \\type T4 = T2<("[|/*2*/|]")>;
        \\type T5 = T2<(("[|/*3*/|]"))>;
        \\type T6 = T2<((("[|/*4*/|]")))>;
        \\
        \\type T7<P extends T1, K extends T1> = {};
        \\type T8 = T7<"a", ((("[|/*5*/|]")))>;
        \\
        \\interface Foo {
        \\    a: number;
        \\    b: number;
        \\}
        \\const a: Foo["[|/*6*/|]"];
        \\const b: Foo[("[|/*7*/|]")];
        \\const b: Foo[(("[|/*8*/|]"))];
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
//                 &.{
//                     .Label = "a",
//                 },
//                 &.{
//                     .Label = "b",
//                 },
//                 &.{
//                     .Label = "c",
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
//             .Exact = &.{
//                 &.{
//                     .Label = "a",
//                 },
//                 &.{
//                     .Label = "b",
//                 },
//                 &.{
//                     .Label = "c",
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
//             .Exact = &.{
//                 &.{
//                     .Label = "a",
//                 },
//                 &.{
//                     .Label = "b",
//                 },
//                 &.{
//                     .Label = "c",
//                 },
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
//             .Exact = &.{
//                 &.{
//                     .Label = "a",
//                 },
//                 &.{
//                     .Label = "b",
//                 },
//                 &.{
//                     .Label = "c",
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "5", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label = "a",
//                 },
//                 &.{
//                     .Label = "b",
//                 },
//                 &.{
//                     .Label = "c",
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "6", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label = "a",
//                 },
//                 &.{
//                     .Label = "b",
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "7", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label = "a",
//                 },
//                 &.{
//                     .Label = "b",
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "8", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label = "a",
//                 },
//                 &.{
//                     .Label = "b",
//                 },
//             },
//         },
//     });
}

test "TestFindAllRefsCommonJsRequire" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\function f() { }
        \\export { f }
        \\// @Filename: /b.js
        \\const { f } = require('./a')
        \\/**/f
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "");
}

test "TestSignatureHelpInferenceJsDocImportTag" {
    const content =
        \\// @allowJS: true
        \\// @checkJs: true
        \\// @module: esnext
        \\// @filename: a.ts
        \\export interface Foo {}
        \\// @filename: b.js
        \\/**
        \\ * @import {
        \\ *     Foo
        \\ * } from './a'
        \\ */
        \\
        \\/**
        \\ * @param {Foo} a
        \\ */
        \\function foo(a) {}
        \\foo(/**/)
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSignatureHelp(undefined);
}

test "TestOrganizeImportsType11" {
    const content =
        \\import {
        \\    type Type1,
        \\    type Type2,
        \\    func4,
        \\    type Type3,
        \\    type Type4,
        \\    type Type5,
        \\    type Type7,
        \\    type Type8,
        \\    type Type9,
        \\    func1,
        \\    func2,
        \\    type Type6,
        \\    func3,
        \\    func5,
        \\    func6,
        \\    func7,
        \\    func8,
        \\    func9,
        \\} from "foo";
        \\interface Use extends Type1, Type2, Type3, Type4, Type5, Type6, Type7, Type8, Type9 {}
        \\console.log(func1, func2, func3, func4, func5, func6, func7, func8, func9);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyOrganizeImports(undefined,
//         "import {\n    type Type1,\n    type Type2,\n    type Type3,\n    type Type4,\n    type Type5,\n    type Type6,\n    type Type7,\n    type Type8,\n    type Type9,\n    func1,\n    func2,\n    func3,\n    func4,\n    func5,\n    func6,\n    func7,\n    func8,\n    func9,\n} from \"foo\";\ninterface Use extends Type1, Type2, Type3, Type4, Type5, Type6, Type7, Type8, Type9 {}\nconsole.log(func1, func2, func3, func4, func5, func6, func7, func8, func9);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
}

test "TestUnusedEnumInFunction1" {
    const content =
        \\// @noUnusedLocals: true
        \\[| function f1 () {
        \\    enum Directions { Up, Down}
        \\} |]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyRangeAfterCodeFix(undefined, "function f1 () {\n}\n", false, 0, 0);
}

test "TestGoToDefinition_untypedModule" {
    const content =
        \\// @Filename: /node_modules/foo/index.js
        \\not read
        \\// @Filename: /a.ts
        \\import { /*def*/f } from "foo";
        \\[|/*use*/f|]();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "use");
}

test "TestImportNameCodeFix_reExport" {
    const content =
        \\// @Filename: /a.ts
        \\export default function foo(): void {}
        \\// @Filename: /b.ts
        \\export { default } from "./a";
        \\// @Filename: /user.ts
        \\[|foo;|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/user.ts");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import foo from \"./a\";\n\nfoo;",
        "import foo from \"./b\";\n\nfoo;",
    }, null );
}

test "TestQuickInfoSignatureWithTrailingComma" {
    const content =
        \\declare function f<T>(a: T): T;
        \\/**/f(2,);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "function f<2>(a: 2): 2", "");
}

test "TestContextuallyTypedParameters" {
    const content =
        \\declare function foo(cb: (this: any, x: number, y: string, z: boolean) => void): void;
        \\
        \\foo(function(this, a, ...args) {
        \\    a/*10*/;
        \\    args/*11*/;
        \\});
        \\
        \\foo(function(this, a, b, ...args) {
        \\    a/*20*/;
        \\    b/*21*/;
        \\    args/*22*/;
        \\});
        \\
        \\foo(function(this, a, b, c, ...args) {
        \\    a/*30*/;
        \\    b/*31*/;
        \\    c/*32*/;
        \\    args/*33*/;
        \\});
        \\
        \\foo(function(a, ...args) {
        \\    a/*40*/;
        \\    args/*41*/;
        \\});
        \\
        \\foo(function(a, b, ...args) {
        \\    a/*50*/;
        \\    b/*51*/;
        \\    args/*52*/;
        \\});
        \\
        \\foo(function(a, b, c, ...args) {
        \\    a/*60*/;
        \\    b/*61*/;
        \\    c/*62*/;
        \\    args/*63*/;
        \\});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "10", "(parameter) a: number", "");
    try f.VerifyQuickInfoAt(undefined, "11", "(parameter) args: [y: string, z: boolean]", "");
    try f.VerifyQuickInfoAt(undefined, "20", "(parameter) a: number", "");
    try f.VerifyQuickInfoAt(undefined, "21", "(parameter) b: string", "");
    try f.VerifyQuickInfoAt(undefined, "22", "(parameter) args: [z: boolean]", "");
    try f.VerifyQuickInfoAt(undefined, "30", "(parameter) a: number", "");
    try f.VerifyQuickInfoAt(undefined, "31", "(parameter) b: string", "");
    try f.VerifyQuickInfoAt(undefined, "32", "(parameter) c: boolean", "");
    try f.VerifyQuickInfoAt(undefined, "33", "(parameter) args: []", "");
    try f.VerifyQuickInfoAt(undefined, "40", "(parameter) a: number", "");
    try f.VerifyQuickInfoAt(undefined, "41", "(parameter) args: [y: string, z: boolean]", "");
    try f.VerifyQuickInfoAt(undefined, "50", "(parameter) a: number", "");
    try f.VerifyQuickInfoAt(undefined, "51", "(parameter) b: string", "");
    try f.VerifyQuickInfoAt(undefined, "52", "(parameter) args: [z: boolean]", "");
    try f.VerifyQuickInfoAt(undefined, "60", "(parameter) a: number", "");
    try f.VerifyQuickInfoAt(undefined, "61", "(parameter) b: string", "");
    try f.VerifyQuickInfoAt(undefined, "62", "(parameter) c: boolean", "");
    try f.VerifyQuickInfoAt(undefined, "63", "(parameter) args: []", "");
}

test "TestCodeFixNegativeReplaceQualifiedNameWithIndexedAccessType01" {
    const content =
        \\namespace Container {
        \\    export interface Foo {
        \\        bar: string;
        \\    }
        \\}
        \\const x: [|Container.Foo.bar|] = ""
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined);
}

test "TestJsdocDeprecated_suggestion20" {
    const content =
        \\// @module: esnext
        \\// @filename: /a.ts
        \\export default function a() {}
        \\// @filename: /b.ts
        \\import _a from "./a";
        \\export {
        \\    /** @deprecated a is deprecated */
        \\    _a as a,
        \\};
        \\/** @deprecated b is deprecated */
        \\export const b = (): void => {};
        \\// @filename: /c.ts
        \\import * as _ from "./b";
        \\
        \\_.[|a|]()
        \\_.[|b|]()
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/c.ts");
    // try f.VerifySuggestionDiagnostics(undefined, []*.{
//         .{
//             .Code =    &.{.Integer = undefined(int32(6385))},
//             .Message = .{.String = undefined("'a' is deprecated.")},
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//             .Range =   f.Ranges()[0].LSRange,
//         },
//         .{
//             .Code =    &.{.Integer = undefined(int32(6385))},
//             .Message = .{.String = undefined("'b' is deprecated.")},
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//             .Range =   f.Ranges()[1].LSRange,
//         },
//     });
}

test "TestGetOccurrencesIsDefinitionOfParameter" {
    const content =
        \\function f(/*1*/x: number) {
        \\  return /*2*/x + 1
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestQuickInfoJsDocTextFormatting1" {
    const content =
        \\/**
        \\ * @param {number} var1 **Highlighted text**
        \\ * @param {string} var2 Another **Highlighted text**
        \\*/
        \\function f1(var1, var2) { }
        \\
        \\/**
        \\ * @param {number} var1 *Regular text with an asterisk
        \\ * @param {string} var2 Another *Regular text with an asterisk
        \\*/
        \\function f2(var1, var2) { }
        \\
        \\/**
        \\ * @param {number} var1 
        \\ * *Regular text with an asterisk
        \\ * @param {string} var2 
        \\ * Another *Regular text with an asterisk
        \\*/
        \\function f3(var1, var2) { }
        \\
        \\/**
        \\ * @param {number} var1 
        \\ * **Highlighted text**
        \\ * @param {string} var2 
        \\ * Another **Highlighted text**
        \\*/
        \\function f4(var1, var2) { }
        \\
        \\/**
        \\ * @param {number} var1 
        \\   **Highlighted text**
        \\ * @param {string} var2 
        \\   Another **Highlighted text**
        \\*/
        \\function f5(var1, var2) { }
        \\
        \\f1(/*1*/);
        \\f2(/*2*/);
        \\f3(/*3*/);
        \\f4(/*4*/);
        \\f5(/*5*/);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSignatureHelp(undefined);
}

test "TestGetEditsForFileRename_js_simple" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\import b from "./b.js";
        \\// @Filename: /b.js
        \\module.exports = 1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyWillRenameFilesEdits(undefined, "/b.js", "/c.js", .{
//         .@"/a.js" = "import b from \"./c.js\";",
//     }, null );
}

test "TestJsxTagNameCompletionUnclosed" {
    const content =
        \\//@Filename: file.tsx
        \\interface NestedInterface {
        \\    Foo: NestedInterface;
        \\    (props: {}): any;
        \\}
        \\
        \\declare const Foo: NestedInterface;
        \\
        \\function fn1() {
        \\    return <Foo>
        \\        </*1*/
        \\    </Foo>
        \\}
        \\function fn2() {
        \\    return <Foo>
        \\        <Fo/*2*/
        \\    </Foo>
        \\}
        \\function fn3() {
        \\    return <Foo>
        \\        <Foo./*3*/
        \\    </Foo>
        \\}
        \\function fn4() {
        \\    return <Foo>
        \\        <Foo.F/*4*/
        \\    </Foo>
        \\}
        \\function fn5() {
        \\    return <Foo>
        \\        <Foo.Foo./*5*/
        \\    </Foo>
        \\}
        \\function fn6() {
        \\    return <Foo>
        \\        <Foo.Foo.F/*6*/
        \\    </Foo>
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
//                     .Label =  "Foo",
//                     .Detail = undefined("const Foo: NestedInterface"),
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
//                     .Label =  "Foo",
//                     .Detail = undefined("const Foo: NestedInterface"),
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
//                     .Label =  "Foo",
//                     .Detail = undefined("(property) NestedInterface.Foo: NestedInterface"),
//                 },
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
//                     .Label =  "Foo",
//                     .Detail = undefined("(property) NestedInterface.Foo: NestedInterface"),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "5", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "Foo",
//                     .Detail = undefined("(property) NestedInterface.Foo: NestedInterface"),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "6", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "Foo",
//                     .Detail = undefined("(property) NestedInterface.Foo: NestedInterface"),
//                 },
//             },
//         },
//     });
}

test "TestIndentAfterFunctionClosingBraces" {
    const content =
        \\class foo {
        \\    public f() {
        \\        return 0;
        \\    /*1*/}/*2*/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "2");
    _ = f.InsertLine(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCurrentLineContent(undefined, "    }");
}

test "TestFindAllRefs_importType_js1" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: /a.js
        \\module.exports = class /**/C {};
        \\module.exports.D = class D {};
        \\// @Filename: /b.js
        \\/** @type {import("./a")} */
        \\const x = 0;
        \\/** @type {import("./a").D} */
        \\const y = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyNoErrors(undefined);
    // try f.VerifyBaselineFindAllReferences(undefined, "");
}

test "TestGetOccurrencesIsDefinitionOfClass" {
    const content =
        \\/*1*/class /*2*/C {
        \\    n: number;
        \\    constructor() {
        \\        this.n = 12;
        \\    }
        \\}
        \\let c = new /*3*/C();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestCodeFixClassImplementInterfaceMappedType2" {
    const content =
        \\type ListenerTemplate<T, S extends string, I extends string = "${1}"> = {
        \\    [K in keyof T as K extends string
        \\        ? S extends 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'ClickEventSupport'",
        .NewRangeContent = "class C implements ClickEventSupport {\n    addClickListener: (listener: (payload: \"some-click-event-payload\") => void) => void;\n    removeClickListener: (listener: (payload: \"some-click-event-payload\") => void) => void;\n}",
        .Index = 0,
    });
}

test "TestGetPropertySymbolsFromBaseTypesDoesntCrash" {
    const content =
        \\// @Filename: file1.ts
        \\class ClassA implements IInterface {
        \\    private [|value|]: number;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestCodeFixClassImplementInterfaceMultipleImplementsIntersection1" {
    const content =
        \\interface I1 {
        \\    x: number;
        \\}
        \\interface I2 {
        \\    x: string;
        \\}
        \\
        \\class C implements I1,I2 {[| |]}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFixAvailable(undefined, &.{"Implement interface 'I1'", "Implement interface 'I2'"});
}

test "TestSmartSelection_emptyRanges" {
    const content =
        \\class HomePage {
        \\  componentDidMount(/*1*/) {
        \\    if (this.props.username/*2*/) {
        \\      return '/*3*/';
        \\    }
        \\  }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSelectionRanges(undefined);
}

test "TestCodeFixMissingTypeAnnotationOnExports9" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\function foo( ){
        \\    return 42;
        \\}
        \\const a = foo();
        \\export = a;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Add annotation of type 'number'",
        .NewFileContent = "function foo( ){\n    return 42;\n}\nconst a: number = foo();\nexport = a;",
        .Index = 0,
    });
}

test "TestSmartSelection_JSDocTags7" {
    const content =
        \\/**
        \\ * @constructor
        \\ * @param {/**/number} data
        \\ */
        \\function Foo(data) {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSelectionRanges(undefined);
}

test "TestSignatureHelpIncompleteCalls" {
    const content =
        \\namespace IncompleteCalls {
        \\    class Foo {
        \\        public f1() { }
        \\        public f2(n: number): number { return 0; }
        \\        public f3(n: number, s: string) : string { return ""; }
        \\    }
        \\    var x = new Foo();
        \\    x.f1();
        \\    x.f2(5);
        \\    x.f3(5, "");
        \\    x.f1(/*incompleteCalls1*/
        \\    x.f2(5,/*incompleteCalls2*/
        \\    x.f3(5,/*incompleteCalls3*/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "incompleteCalls1");
    // try f.VerifySignatureHelp(undefined, .{.Text = "f1(): void", .ParameterCount = 0});
    _ = f.GoToMarker(undefined, "incompleteCalls2");
    // try f.VerifySignatureHelp(undefined, .{.Text = "f2(n: number): number", .ParameterCount = 1});
    _ = f.GoToMarker(undefined, "incompleteCalls3");
    // try f.VerifySignatureHelp(undefined, .{.Text = "f3(n: number, s: string): string", .ParameterCount = 2, .ParameterName = "s", .ParameterSpan = "s: string"});
}

test "TestAnnotateWithTypeFromJSDoc2" {
    const content =
        \\// @Filename: test123.ts
        \\/** @type {number} */
        \\var [|x|]: string;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifySuggestionDiagnostics(undefined, null);
}

test "TestInlayHintsEnumMemberValue" {
    const content =
        \\enum E {
        \\    A,
        \\    AA,
        \\    B = 10,
        \\    BB,
        \\    C = 'C',
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayEnumMemberValueHints = core.TSTrue}});
}

test "TestSmartSelection_functionParams2" {
    const content =
        \\function f(
        \\  a,
        \\  /**/b
        \\) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSelectionRanges(undefined);
}

test "TestGetOccurrencesIsDefinitionOfInterfaceClassMerge" {
    const content =
        \\/*1*/interface /*2*/Numbers {
        \\    p: number;
        \\}
        \\/*3*/interface /*4*/Numbers {
        \\    m: number;
        \\}
        \\/*5*/class /*6*/Numbers {
        \\    f(n: number) {
        \\        return this.p + this.m + n;
        \\    }
        \\}
        \\let i: /*7*/Numbers = new /*8*/Numbers();
        \\let x = i.f(i.p + i.m);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5", "6", "7", "8");
}

test "TestReferencesForIndexProperty3" {
    const content =
        \\interface Object {
        \\    /*1*/toMyString();
        \\}
        \\
        \\var y: Object;
        \\y./*2*/toMyString();
        \\
        \\var x = {};
        \\x["/*3*/toMyString"]();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestJsDocIndentationPreservation1" {
    const content =
        \\// @allowJs: true
        \\// @Filename: Foo.js
        \\/**
        \\ * Does some stuff.
        \\ *     Second line.
        \\ *     Third line.
        \\ */
        \\function foo/**/(){}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyQuickInfoIs(undefined, "function foo(): void", "Does some stuff.\n    Second line.\n\tThird line.");
}

test "TestGoToDefinitionInTypeArgument" {
    const content =
        \\class /*fooDefinition*/Foo<T> { }
        \\
        \\class /*barDefinition*/Bar { }
        \\
        \\var x = new Fo/*fooReference*/o<Ba/*barReference*/r>();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, false, "barReference", "fooReference");
}

test "TestDocumentHighlightInKeyword" {
    const content =
        \\export type Foo<T> = {
        \\    [K [|in|] keyof T]: any;
        \\}
        \\
        \\"a" [|in|] {};
        \\
        \\for (let a [|in|] {}) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestEsModuleInteropFindAllReferences" {
    const content =
        \\// @esModuleInterop: true
        \\// @Filename: /abc.d.ts
        \\declare module "a" {
        \\    /*1*/export const /*2*/x: number;
        \\}
        \\// @Filename: /b.ts
        \\import a from "a";
        \\a./*3*/x;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestTsxFindAllReferences11" {
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
        \\interface ClickableProps {
        \\    children?: string;
        \\    className?: string;
        \\}
        \\interface ButtonProps extends ClickableProps {
        \\    onClick(event?: React.MouseEvent<HTMLButtonElement>): void;
        \\}
        \\interface LinkProps extends ClickableProps {
        \\    goTo: string;
        \\}
        \\declare function MainButton(buttonProps: ButtonProps): JSX.Element;
        \\declare function MainButton(linkProps: LinkProps): JSX.Element;
        \\declare function MainButton(props: ButtonProps | LinkProps): JSX.Element;
        \\let opt = <MainButton /*1*/wrong />;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestAutoImportFileExcludePatterns12" {
    const content =
        \\// @Filename: /src/vs/test.ts
        \\import { Parts } from './parts';
        \\export class /**/Extended implements Parts {
        \\}
        \\// @Filename: /src/vs/parts.ts
        \\import { Event } from '../thing';
        \\export interface Parts {
        \\    readonly options: Event;
        \\}
        \\// @Filename: /src/event/event.ts
        \\export interface Event {
        \\    (): string;
        \\}
        \\// @Filename: /src/thing.ts
        \\import { Event } from '../event/event';
        \\export { Event };
        \\// @Filename: /src/a.ts
        \\import './thing'
        \\declare module './thing' {
        \\    interface Event {
        \\        c: string;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'Parts'",
        .NewFileContent = "import { Parts } from './parts';\nexport class Extended implements Parts {\n    options: Event;\n}",
        .Index =           0,
        .UserPreferences = &.{.AutoImportFileExcludePatterns = &.{"src/thing.ts"}},
    });
}

test "TestCompletionsGenericIndexedAccess5" {
    const content =
        \\interface CustomElements {
        \\  'component-one': {
        \\      foo?: string;
        \\  },
        \\  'component-two': {
        \\      bar?: string;
        \\  }
        \\}
        \\
        \\interface Options<T extends keyof CustomElements> {
        \\    props?: {} & { x: CustomElements[(T extends string ? T : never) & string][] }['x'];
        \\}
        \\
        \\declare function f<T extends keyof CustomElements>(k: T, options: Options<T>): void;
        \\
        \\f("component-one", {
        \\    props: [{
        \\        /**/
        \\    }]
        \\})
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
//                     .Label =      "foo?",
//                     .InsertText = undefined("foo"),
//                     .FilterText = undefined("foo"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//             },
//         },
//     });
}

test "TestAutoImportPackageJsonImportsCaseSensitivity" {
    const content =
        \\// @module: node18
        \\// @allowImportingTsExtensions: true
        \\// @Filename: /package.json
        \\{
        \\  "type": "module",
        \\  "imports": {
        \\    "#src/*": "./SRC/*"
        \\  }
        \\}
        \\// @Filename: /src/add.ts
        \\export function add(a: number, b: number) {}
        \\// @Filename: /src/index.ts
        \\add/*imports*/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyImportFixModuleSpecifiers(undefined, "imports", &.{"#src/add.ts"}, &.{.ImportModuleSpecifierPreference = "non-relative"});
}

test "TestCompletionInsideFunctionContainsArguments" {
    const content =
        \\function testArguments() {/*1*/}
        \\/*2*/
        \\function testNestedArguments() {
        \\  function nestedfunction(){/*3*/}
        \\}
        \\function f() {
        \\    let g = () => /*4*/
        \\}
        \\let g = () => /*5*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"1", "3", "4"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "arguments",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"2", "5"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Excludes = &.{
//                 "arguments",
//             },
//         },
//     });
}

test "TestNavigationBarItemsClass2" {
    const content =
        \\class Foo {}
        \\function Foo() {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestCompletionForStringLiteralNonrelativeImport18" {
    const content =
        \\// @Filename: tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\       "paths": {
        \\           "/*": ["./*"]
        \\       },
        \\    }
        \\}
        \\// @Filename: test0.ts
        \\import * as foo1 from "/path/w/*first*/
        \\// @Filename: path/whatever.ts
        \\export {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"first"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "whatever",
//             },
//         },
//     });
}

test "TestAutoImportProvider1" {
    const content =
        \\// @Filename: /home/src/workspaces/project/node_modules/@angular/forms/package.json
        \\{ "name": "@angular/forms", "typings": "./forms.d.ts" }
        \\// @Filename: /home/src/workspaces/project/node_modules/@angular/forms/forms.d.ts
        \\export class PatternValidator {}
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{ "compilerOptions": { "lib": ["es5"] } }
        \\// @Filename: /home/src/workspaces/project/package.json
        \\{ "dependencies": { "@angular/forms": "*" } }
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\PatternValidator/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToMarker(undefined, "");
    // f.GetOptions();
    // f.Configure(undefined, opts654);
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { PatternValidator } from \"@angular/forms\";\n\nPatternValidator",
    }, null );
}

test "TestFormattingOnStatementsWithNoSemicolon" {
    const content =
        \\/*1*/do
        \\     { var a/*2*/
        \\/*3*/}   while (1)
        \\/*4*/function f() {
        \\/*5*/    var s = 1
        \\/*6*/            }
        \\/*7*/switch (t) {
        \\/*8*/    case 1:
        \\/*9*/{
        \\/*10*/test
        \\/*11*/}
        \\/*12*/}
        \\/*13*/do{do{do{}while(a!==b)}while(a!==b)}while(a!==b)
        \\/*14*/do{
        \\/*15*/do{
        \\/*16*/do{
        \\/*17*/}while(a!==b)
        \\/*18*/}while(a!==b)
        \\/*19*/}while(a!==b)
        \\/*20*/for(var i=0;i<10;i++){
        \\/*21*/for(var j=0;j<10;j++){
        \\/*22*/j-=i
        \\/*23*/}/*24*/}
        \\/*25*/function foo() {
        \\/*26*/try {
        \\/*27*/x+=2
        \\/*28*/}
        \\/*29*/catch( e){
        \\/*30*/x+=2
        \\/*31*/}finally {
        \\/*32*/x+=2
        \\/*33*/}
        \\/*34*/}
        \\/*35*/do     { var a }   while (1)
        \\    foo(function (file) {/*49*/
        \\        return 0/*50*/
        \\    }).then(function (doc) {/*51*/
        \\        return 1/*52*/
        \\    });/*53*/
        \\/*54*/if(1)
        \\/*55*/if(1)
        \\/*56*/x++
        \\/*57*/else
        \\/*58*/if(1)
        \\/*59*/x+=2
        \\/*60*/else
        \\/*61*/x+=2
        \\
        \\
        \\
        \\/*62*/;
        \\         do do do do/*63*/
        \\                test;/*64*/
        \\            while (0)/*65*/
        \\         while (0)/*66*/
        \\            while (0)/*67*/
        \\         while (0)/*68*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCurrentLineContent(undefined, "do {");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyCurrentLineContent(undefined, "    var a");
    _ = f.GoToMarker(undefined, "3");
    try f.VerifyCurrentLineContent(undefined, "} while (1)");
    _ = f.GoToMarker(undefined, "4");
    try f.VerifyCurrentLineContent(undefined, "function f() {");
    _ = f.GoToMarker(undefined, "5");
    try f.VerifyCurrentLineContent(undefined, "    var s = 1");
    _ = f.GoToMarker(undefined, "6");
    try f.VerifyCurrentLineContent(undefined, "}");
    _ = f.GoToMarker(undefined, "7");
    try f.VerifyCurrentLineContent(undefined, "switch (t) {");
    _ = f.GoToMarker(undefined, "8");
    try f.VerifyCurrentLineContent(undefined, "    case 1:");
    _ = f.GoToMarker(undefined, "9");
    try f.VerifyCurrentLineContent(undefined, "        {");
    _ = f.GoToMarker(undefined, "10");
    try f.VerifyCurrentLineContent(undefined, "            test");
    _ = f.GoToMarker(undefined, "11");
    try f.VerifyCurrentLineContent(undefined, "        }");
    _ = f.GoToMarker(undefined, "12");
    try f.VerifyCurrentLineContent(undefined, "}");
    _ = f.GoToMarker(undefined, "13");
    try f.VerifyCurrentLineContent(undefined, "do { do { do { } while (a !== b) } while (a !== b) } while (a !== b)");
    _ = f.GoToMarker(undefined, "14");
    try f.VerifyCurrentLineContent(undefined, "do {");
    _ = f.GoToMarker(undefined, "15");
    try f.VerifyCurrentLineContent(undefined, "    do {");
    _ = f.GoToMarker(undefined, "16");
    try f.VerifyCurrentLineContent(undefined, "        do {");
    _ = f.GoToMarker(undefined, "17");
    try f.VerifyCurrentLineContent(undefined, "        } while (a !== b)");
    _ = f.GoToMarker(undefined, "18");
    try f.VerifyCurrentLineContent(undefined, "    } while (a !== b)");
    _ = f.GoToMarker(undefined, "19");
    try f.VerifyCurrentLineContent(undefined, "} while (a !== b)");
    _ = f.GoToMarker(undefined, "20");
    try f.VerifyCurrentLineContent(undefined, "for (var i = 0; i < 10; i++) {");
    _ = f.GoToMarker(undefined, "21");
    try f.VerifyCurrentLineContent(undefined, "    for (var j = 0; j < 10; j++) {");
    _ = f.GoToMarker(undefined, "22");
    try f.VerifyCurrentLineContent(undefined, "        j -= i");
    _ = f.GoToMarker(undefined, "23");
    try f.VerifyCurrentLineContent(undefined, "    }");
    _ = f.GoToMarker(undefined, "24");
    try f.VerifyCurrentLineContent(undefined, "    }");
    _ = f.GoToMarker(undefined, "25");
    try f.VerifyCurrentLineContent(undefined, "function foo() {");
    _ = f.GoToMarker(undefined, "26");
    try f.VerifyCurrentLineContent(undefined, "    try {");
    _ = f.GoToMarker(undefined, "27");
    try f.VerifyCurrentLineContent(undefined, "        x += 2");
    _ = f.GoToMarker(undefined, "28");
    try f.VerifyCurrentLineContent(undefined, "    }");
    _ = f.GoToMarker(undefined, "29");
    try f.VerifyCurrentLineContent(undefined, "    catch (e) {");
    _ = f.GoToMarker(undefined, "30");
    try f.VerifyCurrentLineContent(undefined, "        x += 2");
    _ = f.GoToMarker(undefined, "31");
    try f.VerifyCurrentLineContent(undefined, "    } finally {");
    _ = f.GoToMarker(undefined, "32");
    try f.VerifyCurrentLineContent(undefined, "        x += 2");
    _ = f.GoToMarker(undefined, "33");
    try f.VerifyCurrentLineContent(undefined, "    }");
    _ = f.GoToMarker(undefined, "34");
    try f.VerifyCurrentLineContent(undefined, "}");
    _ = f.GoToMarker(undefined, "35");
    try f.VerifyCurrentLineContent(undefined, "do { var a } while (1)");
    _ = f.GoToMarker(undefined, "49");
    try f.VerifyCurrentLineContent(undefined, "foo(function(file) {");
    _ = f.GoToMarker(undefined, "50");
    try f.VerifyCurrentLineContent(undefined, "    return 0");
    _ = f.GoToMarker(undefined, "51");
    try f.VerifyCurrentLineContent(undefined, "}).then(function(doc) {");
    _ = f.GoToMarker(undefined, "52");
    try f.VerifyCurrentLineContent(undefined, "    return 1");
    _ = f.GoToMarker(undefined, "53");
    try f.VerifyCurrentLineContent(undefined, "});");
    _ = f.GoToMarker(undefined, "54");
    try f.VerifyCurrentLineContent(undefined, "if (1)");
    _ = f.GoToMarker(undefined, "55");
    try f.VerifyCurrentLineContent(undefined, "    if (1)");
    _ = f.GoToMarker(undefined, "56");
    try f.VerifyCurrentLineContent(undefined, "        x++");
    _ = f.GoToMarker(undefined, "57");
    try f.VerifyCurrentLineContent(undefined, "    else");
    _ = f.GoToMarker(undefined, "58");
    try f.VerifyCurrentLineContent(undefined, "        if (1)");
    _ = f.GoToMarker(undefined, "59");
    try f.VerifyCurrentLineContent(undefined, "            x += 2");
    _ = f.GoToMarker(undefined, "60");
    try f.VerifyCurrentLineContent(undefined, "        else");
    _ = f.GoToMarker(undefined, "61");
    try f.VerifyCurrentLineContent(undefined, "            x += 2");
    _ = f.GoToMarker(undefined, "62");
    try f.VerifyCurrentLineContent(undefined, "                ;");
    _ = f.GoToMarker(undefined, "63");
    try f.VerifyCurrentLineContent(undefined, "do do do do");
    _ = f.GoToMarker(undefined, "64");
    try f.VerifyCurrentLineContent(undefined, "    test;");
    _ = f.GoToMarker(undefined, "65");
    try f.VerifyCurrentLineContent(undefined, "while (0)");
    _ = f.GoToMarker(undefined, "66");
    try f.VerifyCurrentLineContent(undefined, "while (0)");
    _ = f.GoToMarker(undefined, "67");
    try f.VerifyCurrentLineContent(undefined, "while (0)");
    _ = f.GoToMarker(undefined, "68");
    try f.VerifyCurrentLineContent(undefined, "while (0)");
}

test "TestGoToImplementationInterface_04" {
    const content =
        \\interface Fo/*interface_definition*/o {
        \\    (a: number): void
        \\}
        \\
        \\var bar: Foo = [|(a) => {/**0*/}|];
        \\
        \\function whatever(x: Foo = [|(a) => {/**1*/}|] ) {
        \\}
        \\
        \\class Bar {
        \\    x: Foo = [|(a) => {/**2*/}|]
        \\
        \\    constructor(public f: Foo = [|function(a) {}|] ) {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "interface_definition");
}

test "TestQuickinfoVerbosityJs" {
    const content =
        \\// @Filename: somefile.js
        \\// @allowJs: true
        \\/**
        \\ * @typedef {Object} SomeType
        \\ * @property {string} prop1
        \\ */
        \\/** @type {SomeType} */
        \\const a/*1*/ = {
        \\    prop1: 'value',
        \\}
        \\/**
        \\ * @typedef {Object} SomeType2/*2*/
        \\ * @property {number} prop2
        \\ * @property {SomeType} prop3
        \\ */
        \\/** @type {SomeType[]} */
        \\const ss = [{ prop1: 'value' }, { prop1: 'value' }];
        \\const d = ss.map((s/*3*/) => s.prop1);
        \\/** @param {SomeType} a
        \\ * @returns {SomeType}
        \\ */
        \\function someFun/*4*/(a) {
        \\    return a;
        \\}
        \\someFun.what = 'what';
        \\class SomeClass/*5*/ {
        \\    /** @type {SomeType2} */
        \\    b;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"1" = .{0, 1}, .@"2" = .{0, 1}, .@"3" = .{0, 1}, .@"4" = .{0, 1}, .@"5" = .{0, 1, 2}});
}

test "TestGetOccurrencesClassExpressionStatic" {
    const content =
        \\let A = class Foo {
        \\    public [|static|] foo;
        \\    [|static|] a;
        \\    constructor(public y: string, private x: string) {
        \\    }
        \\    public method() { }
        \\    private method2() {}
        \\    public [|static|] static() { }
        \\    private [|static|] static2() { }
        \\}
        \\
        \\let B = class D {
        \\    static a;
        \\    constructor(private x: number) {
        \\    }
        \\    private static test() {}
        \\    public static test2() {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestQualifiedName_import_declaration_with_variable_entity_names" {
    const content =
        \\namespace Alpha {
        \\    export var [|{| "name" : "def" |}x|] = 100;
        \\}
        \\
        \\namespace Beta {
        \\    import p = Alpha.[|{| "name" : "import" |}x|];
        \\}
        \\
        \\var x = Alpha.[|{| "name" : "mem" |}x|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "import");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "x",
//                     .Detail = undefined("var Alpha.x: number"),
//                 },
//             },
//         },
//     });
    // try f.VerifyBaselineDocumentHighlights(undefined, null , "import");
    // try f.VerifyBaselineGoToDefinition(undefined, false, "import");
}

test "TestCompletionListInTypeLiteralInTypeParameter6" {
    const content =
        \\interface Foo {
        \\    one: string;
        \\    two: number;
        \\}
        \\
        \\interface Bar<T extends Foo> {
        \\    foo: T;
        \\}
        \\
        \\var foobar: Bar<{ one: string } | {/**/
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
//                 "one",
//                 "two",
//             },
//         },
//     });
}

test "TestCompletionForStringLiteral_quotePreference2" {
    const content =
        \\const a = {
        \\    '#': 'a'
        \\};
        \\a[|./**/|]
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
//                     .Label =      "#",
//                     .InsertText = undefined("['#']"),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "#",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//         .UserPreferences = &.{.QuotePreference = lsutil.QuotePreference("single")},
//     });
}

test "TestQuickInfoOnArgumentsInsideFunction" {
    const content =
        \\function foo(x: string) {
        \\    return /*1*/arguments;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "(local var) arguments: IArguments", "");
}

test "TestCodeFixClassImplementInterfaceTypeParamInstantiation" {
    const content =
        \\interface I<T> {
        \\   x: T;
        \\}
        \\
        \\class C implements I { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined);
}

test "TestTsxQuickInfo5" {
    const content =
        \\//@Filename: file.tsx
        \\// @jsx: preserve
        \\// @noLib: true
        \\declare function ComponentWithTwoAttributes<K,V>(l: {key1: K, value: V}): JSX.Element;
        \\function Baz<T,U>(key1: T, value: U) {
        \\    let a0 = <ComponentWi/*1*/thTwoAttributes k/*2*/ey1={key1} val/*3*/ue={value} />
        \\    let a1 = <ComponentWithTwoAttributes {...{key1, value: value}} key="Component" />
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "function ComponentWithTwoAttributes<T, U>(l: {\n    key1: T;\n    value: U;\n}): JSX.Element", "");
    try f.VerifyQuickInfoAt(undefined, "2", "(property) key1: T", "");
    try f.VerifyQuickInfoAt(undefined, "3", "(property) value: U", "");
}

test "TestTypeCheckAfterResolve" {
    const content =
        \\/*start*/class Point implements /*IPointRef*/IPoint {
        \\    getDist() {
        \\        ssss;
        \\    }
        \\}/*end*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToEOF(undefined);
    _ = f.InsertLine(undefined, "");
    try f.VerifyQuickInfoAt(undefined, "IPointRef", "any", "");
    try f.VerifyErrorExistsAfterMarker(undefined, "IPointRef");
    _ = f.GoToEOF(undefined);
    _ = f.InsertLine(undefined, "");
    try f.VerifyErrorExistsAfterMarker(undefined, "IPointRef");
}

test "TestGenericParameterHelpConstructorCalls" {
    const content =
        \\interface IFoo { }
        \\
        \\class testClass<T extends IFoo, U, M extends IFoo> {
        \\    constructor(a:T, b:U, c:M){ }
        \\}
        \\
        \\// Constructor calls
        \\new testClass</*constructor1*/
        \\new testClass<IFoo, /*constructor2*/
        \\new testClass</*constructor3*/>(null, null, null)
        \\new testClass<,,/*constructor4*/>(null, null, null)
        \\new testClass<IFoo,/*constructor5*/IFoo,IFoo>(null, null, null)
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "constructor1");
    // try f.VerifySignatureHelp(undefined, .{.Text = "testClass<T extends IFoo, U, M extends IFoo>(a: T, b: U, c: M): testClass<T, U, M>", .ParameterName = "T", .ParameterSpan = "T extends IFoo"});
    _ = f.GoToMarker(undefined, "constructor2");
    // try f.VerifySignatureHelp(undefined, .{.ParameterName = "U", .ParameterSpan = "U"});
    _ = f.GoToMarker(undefined, "constructor3");
    // try f.VerifySignatureHelp(undefined, .{.ParameterName = "T", .ParameterSpan = "T extends IFoo"});
    _ = f.GoToMarker(undefined, "constructor4");
    // try f.VerifySignatureHelp(undefined, .{.ParameterName = "M", .ParameterSpan = "M extends IFoo"});
    _ = f.GoToMarker(undefined, "constructor5");
    // try f.VerifySignatureHelp(undefined, .{.ParameterName = "U", .ParameterSpan = "U"});
}

test "TestUnusedImports7FS" {
    const content =
        \\// @noUnusedLocals: true
        \\// @Filename: file2.ts
        \\[| import * as n from "./file1" |]
        \\// @Filename: file1.ts
        \\export class Calculator {
        \\    handleChar() { }
        \\}
        \\export function test() {
        \\}
        \\export default function test2() {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyRangeAfterCodeFix(undefined, "", false, 0, 0);
}

test "TestJsDocForTypeAlias" {
    const content =
        \\/** DOC */
        \\type /**/T = number
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyQuickInfoIs(undefined, "type T = number", "DOC");
}

test "TestQuickInfoExportAssignmentOfGenericInterface" {
    const content =
        \\// @Filename: quickInfoExportAssignmentOfGenericInterface_0.ts
        \\interface Foo<T> {
        \\    a: string;
        \\}
        \\export = Foo;
        \\// @Filename: quickInfoExportAssignmentOfGenericInterface_1.ts
        \\import a = require('./quickInfoExportAssignmentOfGenericInterface_0');
        \\export var /*1*/x: a<a<string>>;
        \\x.a;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "var x: a<a<string>>", "");
}

test "TestFindAllRefsWithLeadingUnderscoreNames8" {
    const content =
        \\(/*1*/function /*2*/__foo() {
        \\    /*3*/__foo();
        \\})
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestMemberListOfExportedClass" {
    const content =
        \\namespace M {
        \\  export class C { public pub = 0; private priv = 1; }
        \\  export var V = 0;
        \\}
        \\
        \\
        \\var c = new M.C();
        \\
        \\c./**/ // test on c.
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
//                     .Label =  "pub",
//                     .Detail = undefined("(property) M.C.pub: number"),
//                 },
//             },
//         },
//     });
}

test "TestGetOccurrencesIsDefinitionOfArrowFunction" {
    const content =
        \\/*1*/var /*2*/f = x => x + 1;
        \\/*3*/f(12);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestBestCommonTypeObjectLiterals1" {
    const content =
        \\var a = { name: 'bob', age: 18 };
        \\var b = { name: 'jim', age: 20 };
        \\var /*1*/c = [a, b];
        \\var a1 = { name: 'bob', age: 18 };
        \\var b1 = { name: 'jim', age: 20, dob: new Date() };
        \\var /*2*/c1 = [a1, b1];
        \\var a2 = { name: 'bob', age: 18, address: 'springfield' };
        \\var b2 = { name: 'jim', age: 20, dob: new Date() };
        \\var /*3*/c2 = [a2, b2];
        \\interface I {
        \\    name: string;
        \\    age: number;
        \\}
        \\var i: I;
        \\var /*4*/c3 = [i, a];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "4", "var c3: I[]", "");
    try f.VerifyQuickInfoAt(undefined, "1", "var c: {\n    name: string;\n    age: number;\n}[]", "");
    try f.VerifyQuickInfoAt(undefined, "2", "var c1: {\n    name: string;\n    age: number;\n}[]", "");
    try f.VerifyQuickInfoAt(undefined, "3", "var c2: ({\n    name: string;\n    age: number;\n    address: string;\n} | {\n    name: string;\n    age: number;\n    dob: Date;\n})[]", "");
    try f.VerifyQuickInfoAt(undefined, "4", "var c3: I[]", "");
}

test "TestCompletionForStringLiteralNonrelativeImport7" {
    const content =
        \\// @baseUrl: tests/cases/fourslash/modules
        \\// @Filename: tests/test0.ts
        \\import * as foo1 from "mod/*import_as0*/
        \\import foo2 = require("mod/*import_equals0*/
        \\var foo3 = require("mod/*require0*/
        \\// @Filename: modules/module.ts
        \\export var x = 5;
        \\// @Filename: package.json
        \\{ "dependencies": { "module-from-node": "latest" } }
        \\// @Filename: node_modules/module-from-node/index.ts
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, f.Markers(), &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "module",
//                 "module-from-node",
//             },
//         },
//     });
}

test "TestNoErrorsAfterCompletionsRequestWithinGenericFunction2" {
    const content =
        \\// @strict: true
        \\
        \\// repro from #50818#issuecomment-1278324638
        \\
        \\declare function func<T extends { foo: 1 }>(arg: T): void;
        \\func({ foo: 1, bar/*1*/: 1 });
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, "2");
    _ = f.VerifyCompletions(undefined, null, null);
    try f.VerifyNoErrors(undefined);
}

test "TestDeprecatedInheritedJSDocOverload" {
    const content =
        \\// @strict: false
        \\interface PartialObserver<T> {}
        \\interface Subscription {}
        \\interface Unsubscribable {}
        \\
        \\export interface Subscribable<T> {
        \\  subscribe(observer?: PartialObserver<T>): Unsubscribable;
        \\  /** @deprecated Base deprecation 1 */
        \\  subscribe(next: null | undefined, error: null | undefined, complete: () => void): Unsubscribable;
        \\  /** @deprecated Base deprecation 2 */
        \\  subscribe(next: null | undefined, error: (error: any) => void, complete?: () => void): Unsubscribable;
        \\  /** @deprecated Base deprecation 3 */
        \\  subscribe(next: (value: T) => void, error: null | undefined, complete: () => void): Unsubscribable;
        \\  subscribe(next?: (value: T) => void, error?: (error: any) => void, complete?: () => void): Unsubscribable;
        \\}
        \\interface ThingWithDeprecations<T> extends Subscribable<T> {
        \\   subscribe(observer?: PartialObserver<T>): Subscription;
        \\   /** @deprecated 'real' deprecation */
        \\   subscribe(next: null | undefined, error: null | undefined, complete: () => void): Subscription;
        \\   /** @deprecated 'real' deprecation */
        \\   subscribe(next: null | undefined, error: (error: any) => void, complete?: () => void): Subscription;
        \\}
        \\declare const a: ThingWithDeprecations<void>
        \\a.subscribe/**/(() => {
        \\  console.log('something happened');
        \\});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestFixExactOptionalUnassignableProperties7" {
    const content =
        \\// @strictNullChecks: true
        \\// @exactOptionalPropertyTypes: true
        \\// @Filename: fixExactOptionalUnassignableProperties6.ts
        \\class Feh {
        \\    _requestFinished(error?: string) {
        \\        this._finishedPromiseCallback({ error/**/ });
        \\    }
        \\    private _finishedPromiseCallback: (arg: { error?: string }) => void = () => {};
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined);
}

test "TestGoToImplementationLocal_06" {
    const content =
        \\declare var [|someVar|]: string;
        \\someVa/*reference*/r
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "reference");
}

test "TestAutoImportPackageJsonImportsLength2" {
    const content =
        \\// @module: node18
        \\// @Filename: /package.json
        \\{
        \\  "imports": {
        \\    "#*": "./src/*.ts"
        \\  }
        \\}
        \\// @Filename: /src/a/b/c/something.ts
        \\export function something(name: string): any;
        \\// @Filename: /a.ts
        \\something/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"#a/b/c/something"}, null );
}

test "TestCompletionListInObjectBindingPattern02" {
    const content =
        \\interface I {
        \\    property1: number;
        \\    property2: string;
        \\}
        \\
        \\var foo: I;
        \\var { property1, /**/ } = foo;
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

test "TestQuickInfoDisplayPartsTypeParameterInFunction" {
    const content =
        \\function /*1*/foo</*2*/U>(/*3*/a: /*4*/U) {
        \\    return /*5*/a;
        \\}
        \\/*6*/foo("Hello");
        \\function /*7*/foo2</*8*/U extends string>(/*9*/a: /*10*/U) {
        \\    return /*11*/a;
        \\}
        \\/*12*/foo2("hello");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestRenameForDefaultExport04" {
    const content =
        \\// @Filename: foo.ts
        \\export default class /**/[|DefaultExportedClass|] {
        \\}
        \\/*
        \\ *  Commenting DefaultExportedClass
        \\ */
        \\
        \\var x: DefaultExportedClass;
        \\
        \\var y = new DefaultExportedClass;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyRenameSucceeded(undefined, null );
}

test "TestGoToDefinitionUndefinedSymbols" {
    const content =
        \\some/*undefinedValue*/Variable;
        \\var a: some/*undefinedType*/Type;
        \\var x = {}; x.some/*undefinedProperty*/Property;
        \\var a: any; a.some/*unkownProperty*/Property;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, f.MarkerNames());
}

test "TestCompletionsCombineOverloads" {
    const content =
        \\interface A { a: number }
        \\interface B { b: number }
        \\declare function f(a: A): void;
        \\declare function f(b: B): void;
        \\f({ /**/ });
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
//                 "b",
//             },
//         },
//     });
}

test "TestCallHierarchyFunction" {
    const content =
        \\function foo() {
        \\    bar();
        \\}
        \\
        \\function /**/bar() {
        \\    baz();
        \\    quxx();
        \\    baz();
        \\}
        \\
        \\function baz() {
        \\}
        \\
        \\function quxx() {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // try f.VerifyBaselineCallHierarchy(undefined);
}

test "TestFormatAsyncComputedMethod" {
    const content =
        \\class C {
        \\    /*method*/async [0]() { }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "method");
    try f.VerifyCurrentLineContent(undefined, "    async [0]() { }");
}

test "TestGetOccurrencesThrow" {
    const content =
        \\function f(a: number) {
        \\    try {
        \\        throw "Hello";
        \\
        \\        try {
        \\            throw 10;
        \\        }
        \\        catch (x) {
        \\            [|return|] 100;
        \\        }
        \\        finally {
        \\            throw 10;
        \\        }
        \\    }
        \\    catch (x) {
        \\        [|throw|] "Something";
        \\    }
        \\    finally {
        \\        [|throw|] "Also something";
        \\    }
        \\    if (a > 0) {
        \\        [|return|] (function () {
        \\            return;
        \\            return;
        \\            return;
        \\
        \\            if (false) {
        \\                return true;
        \\            }
        \\            throw "Hello!";
        \\        })() || true;
        \\    }
        \\
        \\    [|th/**/row|] 10;
        \\
        \\    var unusued = [1, 2, 3, 4].map(x => { throw 4 })
        \\
        \\    [|return|];
        \\    [|return|] true;
        \\    [|throw|] false;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestCompletionInAugmentedClassModule" {
    const content =
        \\declare class m3f { foo(x: number): void }
        \\namespace m3f { export interface I { foo(): void } }
        \\var x: m3f./**/
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
//                 "I",
//             },
//         },
//     });
}

test "TestCompletionListInUnclosedObjectTypeLiteralInSignature01" {
    const content =
        \\interface I<TString, TNumber> {
        \\    [s: string]: TString;
        \\    [s: number]: TNumber;
        \\}
        \\
        \\declare function foo<TString, TNumber>(obj: I<TString, TNumber>): { str: T/*1*/
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

test "TestGoToImplementationInterfaceMethod_00" {
    const content =
        \\interface Foo {
        \\    he/*declaration*/llo: () => void
        \\}
        \\
        \\var bar: Foo = { [|hello|]: helloImpl };
        \\var baz: Foo = { "[|hello|]": helloImpl };
        \\
        \\function helloImpl () {}
        \\
        \\function whatever(x: Foo = { [|hello|]() {/**1*/} }) {
        \\    x.he/*function_call*/llo()
        \\}
        \\
        \\class Bar {
        \\    x: Foo = { [|hello|]() {/*2*/} }
        \\
        \\    constructor(public f: Foo = { [|hello|]() {/**3*/} } ) {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "function_call", "declaration");
}

test "TestCompletionList_getExportsOfModule" {
    const content =
        \\declare module "x" {
        \\    declare var x: number;
        \\    export = x;
        \\}
        \\
        \\let y: /**/
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
//             .Excludes = &.{
//                 "x",
//             },
//         },
//     });
}

test "TestGotoDefinitionPropertyAccessExpressionHeritageClause" {
    const content =
        \\class B {}
        \\function foo() {
        \\    return {/*refB*/B: B};
        \\}
        \\class C extends (foo()).[|/*B*/B|] {}
        \\class C1 extends foo().[|/*B1*/B|] {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "B", "B1");
}

test "TestFindAllRefsExportNotAtTopLevel" {
    const content =
        \\{
        \\    /*1*/export const /*2*/x = 0;
        \\    /*3*/x;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestQuickInfoForJSDocCodefence" {
    const content =
        \\/**
        \\ * @example
        \\ * 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestDuplicateFunctionImplementation" {
    const content =
        \\interface IFoo<T> {
        \\    foo<T>(): T;
        \\}
        \\function foo<string>(/**/): string { return null; }
        \\function foo<T>(x: T): T { return null; }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, "x: string");
}

test "TestRenameObjectSpread" {
    const content =
        \\interface A1 { [|[|{| "contextRangeIndex": 0 |}a|]: number|] };
        \\interface A2 { [|[|{| "contextRangeIndex": 2 |}a|]?: number|] };
        \\let a1: A1;
        \\let a2: A2;
        \\let a12 = { ...a1, ...a2 };
        \\a12.[|a|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[1], f.Ranges()[3], f.Ranges()[4]);
}

test "TestRenameForDefaultExport06" {
    const content =
        \\// @Filename: foo.ts
        \\export default class DefaultExportedClass {
        \\}
        \\/*
        \\ *  Commenting DefaultExportedClass
        \\ */
        \\
        \\var x: DefaultExportedClass;
        \\
        \\var y = new /**/[|DefaultExportedClass|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyRenameSucceeded(undefined, null );
}

test "TestNavigationBarItemsMultilineStringIdentifiers2" {
    const content =
        \\function f(p1: () => any, p2: string) { }
        \\f(() => { }, 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestDocCommentTemplateWithMultipleJSDoc3" {
    const content =
        \\/** @param p */
        \\/*/**/
        \\function foo(p) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyJSDocCompletion(undefined, "", 3, "/** */", null);
}

test "TestMemberListAfterDoubleDot" {
    const content =
        \\../**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, "", null);
}

test "TestRemoveInterfaceExtendsClause" {
    const content =
        \\interface IFoo<T> { }
        \\interface Array<T> /**/extends IFoo<T> { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.DeleteAtCaret(undefined, 15);
}

test "TestFindAllRefsJsThisPropertyAssignment2" {
    const content =
        \\// @allowJs: true
        \\// @noImplicitThis: true
        \\// @Filename: infer.d.ts
        \\export declare function infer(o: { m: Record<string, Function> } & ThisType<{ x: number }>): void;
        \\// @Filename: a.js
        \\import { infer } from "./infer";
        \\infer({
        \\    m: {
        \\        initData() {
        \\            this.x = 1;
        \\            this./*1*/x;
        \\        },
        \\    }
        \\});
        \\// @Filename: b.ts
        \\import { infer } from "./infer";
        \\infer({
        \\    m: {
        \\        initData() {
        \\            this.x = 1;
        \\            this./*2*/x;
        \\        },
        \\    }
        \\});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestFindAllRefsNonModule" {
    const content =
        \\// @checkJs: true
        \\// @Filename: /script.ts
        \\console.log("I'm a script!");
        \\// @Filename: /import.ts
        \\import "./script/*1*/";
        \\// @Filename: /require.js
        \\require("./script/*2*/");
        \\console.log("./script/*3*/");
        \\// @Filename: /tripleSlash.ts
        \\/// <reference path="script.ts" />
        \\// @Filename: /stringLiteral.ts
        \\console.log("./script");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestWhiteSpaceTrimming" {
    const content =
        \\if (true) {     
        \\  //    
        \\   /*err*/}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "err");
    _ = f.Insert(undefined, "\n");
    try f.VerifyCurrentFileContent(undefined, "if (true) {     \n  //    \n\n}");
}

test "TestQuickInfoOnParameterProperties" {
    const content =
        \\interface IFoo {
        \\  /** this is the name of blabla 
        \\   *  - use blabla 
        \\   *  @example blabla
        \\   */
        \\  name?: string;
        \\}
        \\
        \\// test1 should work
        \\class Foo implements IFoo {
        \\  //public name: string = '';
        \\  constructor(
        \\    public na/*1*/me: string, // documentation should leech and work ! 
        \\  ) {
        \\  }
        \\}
        \\
        \\// test2 work
        \\class Foo2 implements IFoo {
        \\  public na/*2*/me: string = ''; // documentation leeched and work ! 
        \\  constructor(
        \\    //public name: string,
        \\  ) {
        \\  }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestCompletionListInTypedObjectLiterals4" {
    const content =
        \\interface MyPoint {
        \\    x1: number;
        \\    y1: number;
        \\}
        \\var p15: MyPoint = {
        \\    "x1": 5,
        \\    /*15*/
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "15", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "y1",
//             },
//         },
//     });
}

test "TestDocCommentTemplateWithMultipleJSDocAndParameters" {
    const content =
        \\/** */
        \\/**
        \\ * 
        \\ * @param p 
        \\ */
        \\/** */
        \\/*/**/
        \\function foo(p) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyJSDocCompletion(undefined, "", 7, "/**\n * \n * @param p\n */", null);
}

test "TestCompletionsAfterKeywordsInBlock" {
    const content =
        \\class C1 {
        \\    method(map: Map<string, string>, key: string, defaultValue: string) {
        \\        try {
        \\            return map.get(key)!;
        \\        }
        \\        catch {
        \\            return default/*1*/
        \\        }
        \\    }
        \\}
        \\class C2 {
        \\    method(map: Map<string, string>, key: string, defaultValue: string) {
        \\        if (map.has(key)) {
        \\            return map.get(key)!;
        \\        }
        \\        else {
        \\            return default/*2*/
        \\        }
        \\    }
        \\}
        \\class C3 {
        \\    method(map: Map<string, string>, key: string, returnValue: string) {
        \\        try {
        \\            return map.get(key)!;
        \\        }
        \\        catch {
        \\            return return/*3*/
        \\        }
        \\    }
        \\}
        \\class C4 {
        \\    method(map: Map<string, string>, key: string, returnValue: string) {
        \\        if (map.has(key)) {
        \\            return map.get(key)!;
        \\        }
        \\        else {
        \\            return return/*4*/
        \\        }
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"1", "2"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =    "defaultValue",
//                     .SortText = undefined(string(ls.SortTextLocationPriority)),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"3", "4"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =    "returnValue",
//                     .SortText = undefined(string(ls.SortTextLocationPriority)),
//                 },
//             },
//         },
//     });
}

test "TestOrganizeImports5" {
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

test "TestCompletionsAssertKeyword" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.ts
        \\ const f = {
        \\    a: 1
        \\};
        \\ import * as thing from "thing" /*0*/
        \\ export { foo } from "foo" /*1*/
        \\ import "foo" as /*2*/
        \\ import "foo" a/*3*/
        \\ import * as that from "that"
        \\ /*4*/
        \\ import * /*5*/ as those from "those"
        \\// @Filename: b.js
        \\ import * as thing from "thing" /*js*/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "0", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =    "assert",
//                     .Kind =     undefined(lsproto.CompletionItemKindKeyword),
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =    "assert",
//                     .Kind =     undefined(lsproto.CompletionItemKindKeyword),
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
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
//             .Excludes = &.{
//                 "assert",
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
//                     .Label =    "assert",
//                     .Kind =     undefined(lsproto.CompletionItemKindKeyword),
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
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
//             .Excludes = &.{
//                 "assert",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "5", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Excludes = &.{
//                 "assert",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "js", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =    "assert",
//                     .Kind =     undefined(lsproto.CompletionItemKindKeyword),
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestGoToDefinitionJsDocImportTag4" {
    const content =
        \\// @allowJS: true
        \\// @checkJs: true
        \\// @Filename: /b.ts
        \\export interface /*2*/A { }
        \\// @Filename: /a.js
        \\/**
        \\ * @import { [|A/*1*/|] } from "./b";
        \\ */
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestCodeFixMissingTypeAnnotationOnExports10" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\function foo() {
        \\    return { x: 1, y: 1 };
        \\}
        \\export default foo();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Extract default export to variable",
        .NewFileContent = "function foo() {\n    return { x: 1, y: 1 };\n}\nconst _default_1: {\n    x: number;\n    y: number;\n} = foo();\nexport default _default_1;",
        .Index = 0,
    });
}

test "TestDuplicateIndexers" {
    const content =
        \\interface I {
        \\    [x: number]: string;
        \\    [x: number]: number;
        \\}
        \\var i: I;
        \\var /**/r = i[1];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "var r: string", "");
}

test "TestCodeFixSpellingJs3" {
    const content =
        \\// @allowjs: true
        \\// @noEmit: true
        \\// @filename: a.js
        \\class Classe {
        \\    non = 'oui'
        \\    methode() {
        \\        // no error on 'this' references
        \\        return this.none
        \\    }
        \\}
        \\class Derivee extends Classe {
        \\    methode() {
        \\        // no error on 'super' references
        \\        return super.none
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyNoErrors(undefined);
}

test "TestPathCompletionsAllowTsExtensions" {
    const content =
        \\// @moduleResolution: bundler
        \\// @allowImportingTsExtensions: true
        \\// @noEmit: true
        \\// @Filename: /project/foo.ts
        \\export const foo = 0;
        \\// @Filename: /project/main.ts
        \\import {} from ".//**/"
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
//                 "foo",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "foo.ts",
//             },
//         },
//         .UserPreferences = &.{.ImportModuleSpecifierEnding = "js"},
//     });
    _ = f.Insert(undefined, "foo.ts\"\nimport {} from \"./");
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "foo.ts",
//             },
//         },
//     });
}

test "TestCodeFixMissingTypeAnnotationOnExports53_nested_generic_types" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\export interface Foo<T, U = T[]> {}
        \\export function foo(x: Map<number, Foo<string>>) {
        \\    return x;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Add return type 'Map<number, Foo<string, string[]>>'",
        .NewFileContent = "export interface Foo<T, U = T[]> {}\nexport function foo(x: Map<number, Foo<string>>): Map<number, Foo<string, string[]>> {\n    return x;\n}",
        .Index = 0,
    });
}

test "TestCodeFixClassImplementInterfaceNamespaceConflict" {
    const content =
        \\namespace N1 {
        \\    export interface I1 { x: number; }
        \\}
        \\interface I1 {
        \\    f1();
        \\}
        \\class C1 implements N1.I1 {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'N1.I1'",
        .NewFileContent = "namespace N1 {\n    export interface I1 { x: number; }\n}\ninterface I1 {\n    f1();\n}\nclass C1 implements N1.I1 {\n    x: number;\n}",
        .Index = 0,
    });
}

test "TestAutoImportFileExcludePatterns7" {
    const content =
        \\// @Filename: /src/vs/workbench/test.ts
        \\import { Parts } from './parts';
        \\export class /**/EditorParts implements Parts { }
        \\// @Filename: /src/vs/event/event.ts
        \\export interface Event {
        \\    (): string;
        \\}
        \\// @Filename: /src/vs/workbench/parts.ts
        \\import { Event } from '../event/event';
        \\export interface Parts {
        \\    readonly options: Event;
        \\}
        \\// @Filename: /src/vs/workbench/workbench.ts
        \\import { Event } from '../event/event';
        \\export { Event };
        \\// @Filename: /src/vs/workbench/workbench2.ts
        \\import { Event } from '../event/event';
        \\export { Event };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'Parts'",
        .NewFileContent = "import { Event } from '../event/event';\nimport { Parts } from './parts';\nexport class EditorParts implements Parts {\n    options: Event;\n}",
        .Index =           0,
        .UserPreferences = &.{.AutoImportFileExcludePatterns = &.{"src/vs/workbench/workbench*"}},
    });
}

test "TestQuickInfoInFunctionTypeReference" {
    const content =
        \\function map(fn: (variab/*1*/le1: string) => void) {
        \\}
        \\var x = <{ (fn: (va/*2*/riable2: string) => void, a: string): void; }> () => { };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "(parameter) variable1: string", "");
    try f.VerifyQuickInfoAt(undefined, "2", "(parameter) variable2: string", "");
}

test "TestDuplicatePackageServices" {
    const content =
        \\// @noImplicitReferences: true
        \\// @Filename: /node_modules/a/index.d.ts
        \\import [|X/*useAX*/|] from "x";
        \\export function a(x: X): void;
        \\// @Filename: /node_modules/a/node_modules/x/index.d.ts
        \\export default class /*defAX*/X {
        \\    private x: number;
        \\}
        \\// @Filename: /node_modules/a/node_modules/x/package.json
        \\{ "name": "x", "version": "1.2.3" }
        \\// @Filename: /node_modules/b/index.d.ts
        \\import [|X/*useBX*/|] from "x";
        \\export const b: X;
        \\// @Filename: /node_modules/b/node_modules/x/index.d.ts
        \\export default class /*defBX*/X {
        \\    private x: number;
        \\}
        \\// @Filename: /node_modules/b/node_modules/x/package.json
        \\{ "name": "x", "version": "1.2.3" }
        \\// @Filename: /src/a.ts
        \\import { a } from "a";
        \\import { b } from "b";
        \\a(/*error*/b);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/src/a.ts");
    try f.VerifyNumberOfErrorsInCurrentFile(undefined, 0);
    // try f.VerifyBaselineFindAllReferences(undefined, "useAX", "defAX", "useBX");
    // try f.VerifyBaselineGoToDefinition(undefined, true, "useAX", "useBX");
}

test "TestImportNameCodeFix_typeOnly2" {
    const content =
        \\// @importsNotUsedAsValues: error
        \\// @Filename: types.ts
        \\export class A {}
        \\// @Filename: index.ts
        \\const a: A = new A();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "index.ts");
    try f.VerifyCodeFixAll(undefined, .{
        .FixID = "fixMissingImport",
        .NewFileContent = "import { A } from \"./types\";\n\nconst a: A = new A();",
    });
}

test "TestRenameCommentsAndStrings3" {
    const content =
        \\///<reference path="./Bar.ts" />
        \\[|function [|{| "contextRangeIndex": 0 |}Bar|]() {
        \\    // This is a reference to [|Bar|] in a comment.
        \\    "this is a reference to Bar in a string"
        \\}|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[1]);
}

test "TestQuickInfoForObjectBindingElementName01" {
    const content =
        \\interface I {
        \\    property1: number;
        \\    property2: string;
        \\}
        \\
        \\var foo: I;
        \\var { /**/property1 } = foo;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyQuickInfoAt(undefined, "", "var property1: number", "");
}

test "TestGetOutliningForTypeLiteral" {
    const content =
        \\type A =[| {
        \\    a: number;
        \\}|]
        \\
        \\type B =[| {
        \\   a:[| {
        \\       a1:[| {
        \\           a2:[| {
        \\               x: number;
        \\               y: number;
        \\           }|]
        \\       }|]
        \\   }|],
        \\   b:[| {
        \\       x: number;
        \\   }|],
        \\   c:[| {
        \\       x: number;
        \\   }|]
        \\}|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyOutliningSpans(undefined);
}

test "TestCompletionsOverridingMethod4" {
    const content =
        \\// @newline: LF
        \\// @Filename: secret.ts
        \\class Secret {
        \\    #secret(): string {
        \\        return "secret";
        \\    }
        \\
        \\    private tell(): string {
        \\        return this.#secret();
        \\    }
        \\
        \\    protected hint(): string {
        \\        return "hint";
        \\    }
        \\
        \\    public refuse(): string {
        \\        return "no comments";
        \\    }
        \\}
        \\
        \\class Gossip extends Secret {
        \\    /* no telling secrets */
        \\    /*a*/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "a", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =      "hint",
//                     .InsertText = undefined("protected hint(): string {\n}"),
//                     .FilterText = undefined("hint"),
//                     .SortText =   undefined(string(ls.SortTextLocationPriority)),
//                 },
//                 &.{
//                     .Label =      "refuse",
//                     .InsertText = undefined("public refuse(): string {\n}"),
//                     .FilterText = undefined("refuse"),
//                     .SortText =   undefined(string(ls.SortTextLocationPriority)),
//                 },
//             },
//             .Excludes = &.{
//                 "tell",
//                 "#secret",
//             },
//         },
//     });
}

test "TestFormattingConditionalOperator" {
    const content =
        \\var x=true?1:2
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToBOF(undefined);
    try f.VerifyCurrentLineContent(undefined, "var x = true ? 1 : 2");
}

test "TestSignatureHelpFilteredTriggers03" {
    const content =
        \\declare class ViewJayEss {
        \\    constructor(obj: object);
        \\}
        \\new ViewJayEss({
        \\    methods: {
        \\        sayHello/**/
        \\    }
        \\});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, "(");
    // try f.VerifyNoSignatureHelpWithContext(undefined, &.{.TriggerKind = lsproto.SignatureHelpTriggerKindTriggerCharacter, .TriggerCharacter = undefined("("), .IsRetrigger = false});
    _ = f.Insert(undefined, ") {},");
    // try f.VerifyNoSignatureHelpWithContext(undefined, &.{.TriggerKind = lsproto.SignatureHelpTriggerKindTriggerCharacter, .TriggerCharacter = undefined(","), .IsRetrigger = false});
}

test "TestStringLiteralCompletionsForGenericConditionalTypesUsingTemplateLiteralTypes" {
    const content =
        \\type PathOf<T, K extends string, P extends string = ""> =
        \\  K extends 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"ts"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "a",
//                 "b",
//                 "b.c",
//             },
//         },
//     });
}

test "TestConsistenceOnIndentionsOfObjectsInAListAfterFormatting" {
    const content =
        \\foo({
        \\}, {/*1*/
        \\});/*2*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCurrentLineContent(undefined, "}, {");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyCurrentLineContent(undefined, "});");
}

test "TestRenameNamedImport" {
    const content =
        \\// @Filename: /home/src/workspaces/project/lib/tsconfig.json
        \\{ "compilerOptions": { "lib": ["es5"] } }
        \\// @Filename: /home/src/workspaces/project/lib/index.ts
        \\const unrelatedLocalVariable = 123;
        \\export const someExportedVariable = unrelatedLocalVariable;
        \\// @Filename: /home/src/workspaces/project/src/tsconfig.json
        \\{ "compilerOptions": { "lib": ["es5"] } }
        \\// @Filename: /home/src/workspaces/project/src/index.ts
        \\import { /*i*/someExportedVariable } from '../lib/index';
        \\someExportedVariable;
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{ "compilerOptions": { "lib": ["es5"] } }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToFile(undefined, "/home/src/workspaces/project/lib/index.ts");
    _ = f.GoToFile(undefined, "/home/src/workspaces/project/src/index.ts");
    // try f.VerifyBaselineRename(undefined, &.{.UseAliasesForRename = core.TSTrue}, "i");
}

test "TestOrganizeImports13" {
    const content =
        \\import {
        \\    Type1,
        \\    Type2,
        \\    func4,
        \\    Type3,
        \\    Type4,
        \\    Type5,
        \\    Type7,
        \\    Type8,
        \\    Type9,
        \\    func1,
        \\    func2,
        \\    Type6,
        \\    func3,
        \\    func5,
        \\    func6,
        \\    func7,
        \\    func8,
        \\    func9,
        \\} from "foo";
        \\interface Use extends Type1, Type2, Type3, Type4, Type5, Type6, Type7, Type8, Type9 {}
        \\console.log(func1, func2, func3, func4, func5, func6, func7, func8, func9);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyOrganizeImports(undefined,
//         "import {\n    Type1,\n    Type2,\n    Type3,\n    Type4,\n    Type5,\n    Type6,\n    Type7,\n    Type8,\n    Type9,\n    func1,\n    func2,\n    func3,\n    func4,\n    func5,\n    func6,\n    func7,\n    func8,\n    func9,\n} from \"foo\";\ninterface Use extends Type1, Type2, Type3, Type4, Type5, Type6, Type7, Type8, Type9 {}\nconsole.log(func1, func2, func3, func4, func5, func6, func7, func8, func9);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
    // try f.VerifyOrganizeImports(undefined,
//         "import {\n    func1,\n    func2,\n    func3,\n    func4,\n    func5,\n    func6,\n    func7,\n    func8,\n    func9,\n    Type1,\n    Type2,\n    Type3,\n    Type4,\n    Type5,\n    Type6,\n    Type7,\n    Type8,\n    Type9,\n} from \"foo\";\ninterface Use extends Type1, Type2, Type3, Type4, Type5, Type6, Type7, Type8, Type9 {}\nconsole.log(func1, func2, func3, func4, func5, func6, func7, func8, func9);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSTrue,
//         },
//     );
}

test "TestImportSuggestionsCache_invalidPackageJson" {
    const content =
        \\// @lib: es5
        \\// @Filename: /home/src/workspaces/project/jsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "lib": ["es5"],
        \\    "module": "commonjs",
        \\    "types": ["*"]
        \\  },
        \\}
        \\// @Filename: /home/src/workspaces/project/node_modules/@types/node/index.d.ts
        \\declare module 'fs' {
        \\  export function readFile(): void;
        \\}
        \\declare module 'util' {
        \\  export function promisify(): void;
        \\}
        \\// @Filename: /home/src/workspaces/project/package.json
        \\{ "mod" }
        \\// @Filename: /home/src/workspaces/project/a.js
        \\
        \\readF/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
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
//                     .Label = "readFile",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "fs",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
}

test "TestIncrementalEditInvocationExpressionAboveInterfaceDeclaration" {
    const content =
        \\// @lib: es5
        \\declare function alert(message?: any): void;
        \\/*1*/
        \\interface Foo {
        \\    setISO8601(dString): Date;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, "alert(");
    // try f.VerifySignatureHelp(undefined, .{.Text = "alert(message?: any): void"});
    try f.VerifyErrorExistsAfterMarker(undefined, "1");
}

test "TestCompletionsLiteralFromInferenceWithinInferredType3" {
    const content =
        \\// @stableTypeOrdering: true
        \\declare function test<T>(a: {
        \\  [K in keyof T]: {
        \\    b?: (keyof T)[];
        \\  };
        \\}): void;
        \\
        \\test({
        \\  foo: {},
        \\  bar: {
        \\    b: ["/*ts*/"],
        \\  },
        \\});
        \\
        \\test({
        \\  foo: {},
        \\  bar: {
        \\    b: [/*ts2*/],
        \\  },
        \\});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"ts"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "bar",
//                 "foo",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"ts2"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "\"bar\"",
//                 "\"foo\"",
//             },
//         },
//     });
}

test "TestCodeFixClassImplementInterfaceMappedTypeIndirectKeys" {
    const content =
        \\type Base = { ax: number; ay: string };
        \\type BaseKeys = keyof Base;
        \\type MappedIndirect = { [K in BaseKeys]: boolean };
        \\class MappedImpl implements MappedIndirect { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'MappedIndirect'",
        .NewFileContent = "type Base = { ax: number; ay: string };\ntype BaseKeys = keyof Base;\ntype MappedIndirect = { [K in BaseKeys]: boolean };\nclass MappedImpl implements MappedIndirect {\n    ax: boolean;\n    ay: boolean;\n}",
        .Index = 0,
    });
}

test "TestThisBindingInLambda" {
    const content =
        \\class Greeter {
        \\    constructor() { 
        \\        [].forEach((anything)=>{
        \\            console.log(th/**/is);
        \\        });
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "this: this", "");
}

test "TestJsdocLink5" {
    const content =
        \\function g() { }
        \\/**
        \\ * {@link g()} {@link g() } {@link g ()} {@link g () 0} {@link g()1} {@link g() 2}
        \\ * {@link u()} {@link u() } {@link u ()} {@link u () 0} {@link u()1} {@link u() 2}
        \\ */
        \\function f(x) {
        \\}
        \\f/*3*/()
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestCompletionsImport_jsxOpeningTagImportDefault" {
    const content =
        \\// @module: commonjs
        \\// @jsx: react
        \\// @Filename: /component.tsx
        \\export default function (props: any) {}
        \\// @Filename: /index.tsx
        \\export function Index() {
        \\    return <Component/**/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label = "Component",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./component",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//             .Excludes = &.{
//                 "component",
//             },
//         },
//     });
    // try f.VerifyApplyCodeActionFromCompletion(undefined, undefined(""), &.{
//         .Name =        "Component",
//         .Source =      "./component",
//         .Description = "Add import from \"./component\"",
//         .NewFileContent = undefined("import Component from \"./component\";\n\nexport function Index() {\n    return <Component\n}"),
//     });
}

test "TestDocCommentTemplate_insideEmptyComment" {
    const content =
        \\/** /**/ */
        \\function f(p) { return p; }
        \\
        \\/** Doc/*1*/ */
        \\function g(p) { return p; }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyJSDocCompletion(undefined, "", 7, "/**\n * \n * @param p\n * @returns\n */", null);
    // try f.VerifyNoJSDocCompletion(undefined, "1");
}

test "TestGoToImplementationInterface_08" {
    const content =
        \\interface Base {
        \\    hello (): void;
        \\}
        \\
        \\interface A extends Base {}
        \\interface B extends C, A {}
        \\interface C extends B, A {}
        \\
        \\class X implements B {
        \\    [|hello|]() {}
        \\}
        \\
        \\function someFunction(d : A) {
        \\    d.he/*function_call*/llo();
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "function_call");
}

test "TestSemanticModernClassificationInfinityAndNaN" {
    const content =
        \\ Infinity;
        \\ NaN;
        \\
        \\// Regular properties
        \\
        \\const obj1 = {
        \\    Infinity: 100,
        \\    NaN: 200,
        \\    "-Infinity": 300
        \\};
        \\
        \\obj1.Infinity;
        \\obj1.NaN;
        \\obj1["-Infinity"];
        \\
        \\// Shorthand properties
        \\
        \\const obj2 = {
        \\    Infinity,
        \\    NaN,
        \\}
        \\
        \\obj2.Infinity;
        \\obj2.NaN;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "variable.declaration.readonly", .Text = "obj1"},
//         .{.Type = "variable.readonly", .Text = "obj1"},
//         .{.Type = "variable.readonly", .Text = "obj1"},
//         .{.Type = "variable.readonly", .Text = "obj1"},
//         .{.Type = "variable.declaration.readonly", .Text = "obj2"},
//         .{.Type = "variable.readonly", .Text = "obj2"},
//         .{.Type = "variable.readonly", .Text = "obj2"},
//     });
}

test "TestQuickInfoTypedGenericPrototypeMember" {
    const content =
        \\class C<T> {
        \\   foo(x: T) { }
        \\}
        \\var /*1*/x = new C<any>(); // Quick Info for x is C<any>
        \\var /*2*/y = C.prototype; // Quick Info for y is C<{}>
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "var x: C<any>", "");
    try f.VerifyQuickInfoAt(undefined, "2", "var y: C<any>", "");
}

test "TestUpdateSourceFile_jsdocSignature" {
    const content =
        \\/**
        \\ * @callback Cb
        \\ * @return {/**/}
        \\ */
        \\let x;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, "number");
}

test "TestAutoImportCrossProject_paths_toDist" {
    const content =
        \\// @Filename: /home/src/workspaces/project/packages/app/package.json
        \\{ "name": "app", "dependencies": { "dep": "*" } }
        \\// @Filename: /home/src/workspaces/project/packages/app/tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "lib": ["es5"],
        \\    "module": "commonjs",
        \\    "outDir": "dist",
        \\    "rootDir": "src",
        \\    "baseUrl": ".",
        \\    "paths": {
        \\      "dep": ["../dep/src/main"],
        \\      "dep/dist/*": ["../dep/src/*"]
        \\    }
        \\  }
        \\  "references": [{ "path": "../dep" }]
        \\}
        \\// @Filename: /home/src/workspaces/project/packages/app/src/index.ts
        \\dep1/*1*/;
        \\// @Filename: /home/src/workspaces/project/packages/app/src/utils.ts
        \\dep2/*2*/;
        \\// @Filename: /home/src/workspaces/project/packages/app/src/a.ts
        \\import "dep";
        \\// @Filename: /home/src/workspaces/project/packages/dep/package.json
        \\{ "name": "dep", "main": "dist/main.js", "types": "dist/main.d.ts" }
        \\// @Filename: /home/src/workspaces/project/packages/dep/tsconfig.json
        \\{
        \\  "compilerOptions": { "lib": ["es5"], "outDir": "dist", "rootDir": "src", "module": "commonjs" }
        \\}
        \\// @Filename: /home/src/workspaces/project/packages/dep/src/main.ts
        \\import "./sub/folder";
        \\export const dep1 = 0;
        \\// @Filename: /home/src/workspaces/project/packages/dep/src/sub/folder/index.ts
        \\export const dep2 = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { dep1 } from \"dep\";\n\ndep1;",
    }, null );
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { dep2 } from \"dep/dist/sub/folder\";\n\ndep2;",
    }, null );
}

test "TestCompletionsAtTypeArguments" {
    const content =
        \\interface I {
        \\    a: string;
        \\    b: number;
        \\}
        \\type T1 = Pick<I, "/*1*/">;
        \\interface T2 extends Pick<I, "/*2*/"> {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"1", "2"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "a",
//                 "b",
//             },
//         },
//     });
}

test "TestCompletionForStringLiteral16" {
    const content =
        \\interface Foo {
        \\    a: string;
        \\    b: number;
        \\    c: string;
        \\}
        \\
        \\declare function f1<T>(key: keyof T): T;
        \\declare function f2<T>(a: keyof T, b: keyof T): T;
        \\
        \\f1<Foo>("/*1*/",);
        \\f1<Foo>("/*2*/");
        \\f1<Foo>("/*3*/",,,);
        \\f2<Foo>("/*4*/", "/*5*/",);
        \\f2<Foo>("/*6*/", "/*7*/");
        \\f2<Foo>("/*8*/", "/*9*/",,,);
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
//             .Exact = &.{
//                 "a",
//                 "b",
//                 "c",
//             },
//         },
//     });
}

test "TestFindAllRefsObjectBindingElementPropertyName04" {
    const content =
        \\interface I {
        \\    /*0*/property1: number;
        \\    property2: string;
        \\}
        \\
        \\function f({ /*1*/property1: p1 }: I,
        \\           { /*2*/property1 }: I,
        \\           { property1: p2 }) {
        \\
        \\    return /*3*/property1 + 1;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "0", "1", "2", "3");
}

