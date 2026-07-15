const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestGetOccurrencesSuper2" {
    const content =
        \\class SuperType {
        \\    superMethod() {
        \\    }
        \\
        \\    static superStaticMethod() {
        \\        return 10;
        \\    }
        \\}
        \\
        \\class SubType extends SuperType {
        \\    public  prop1 = super.superMethod;
        \\    private prop2 = super.superMethod;
        \\
        \\    constructor() {
        \\        super();
        \\    }
        \\
        \\    public method1() {
        \\        return super.superMethod();
        \\    }
        \\
        \\    private method2() {
        \\        return super.superMethod();
        \\    }
        \\
        \\    public method3() {
        \\        var x = () => super.superMethod();
        \\
        \\        // Bad but still gets highlighted
        \\        function f() {
        \\            super.superMethod();
        \\        }
        \\    }
        \\
        \\    // Bad but still gets highlighted.
        \\    public static statProp1 = [|super|].superStaticMethod;
        \\
        \\    public static staticMethod1() {
        \\        return [|super|].superStaticMethod();
        \\    }
        \\
        \\    private static staticMethod2() {
        \\        return [|supe/**/r|].superStaticMethod();
        \\    }
        \\
        \\    // Are not actually 'super' keywords.
        \\    super = 10;
        \\    static super = 20;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestCompletionWithDotFollowedByNamespaceKeyword" {
    const content =
        \\namespace A {
        \\    function foo() {
        \\        if (true) {
        \\            B./**/
        \\        namespace B {
        \\            export function baz() { }
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
//                 &.{
//                     .Label =  "baz",
//                     .Detail = undefined("function B.baz(): void"),
//                 },
//             },
//         },
//     });
}

test "TestContextuallyTypedFunctionExpressionGeneric1" {
    const content =
        \\interface Comparable<T> {
        \\   compareTo(other: T): T;
        \\}
        \\interface Comparer {
        \\   <T extends Comparable<T>>(x: T, y: T): T;
        \\}
        \\var max2: Comparer = (x/*1*/x, y/*2*/y) => { return x/*3*/x.compareTo(y/*4*/y) };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "(parameter) xx: T extends Comparable<T>", "");
    // f.VerifyQuickInfoAt(undefined, "2", "(parameter) yy: T extends Comparable<T>", "");
    // f.VerifyQuickInfoAt(undefined, "3", "(parameter) xx: T extends Comparable<T>", "");
    // f.VerifyQuickInfoAt(undefined, "4", "(parameter) yy: T extends Comparable<T>", "");
}

test "TestErrorConsistency" {
    const content =
        \\interface Int<T> {
        \\val<U>(f: (t: T) => U): Int<U>;
        \\}
        \\declare var v1: Int<string>;
        \\var /*1*/v2/*2*/: Int<number> = v1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToEOF(undefined);
    _ = f.VerifyErrorExistsBetweenMarkers(undefined, "1", "2");
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
    _ = f.Backspace(undefined, 1);
    _ = f.VerifyErrorExistsBetweenMarkers(undefined, "1", "2");
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
}

test "TestQuickInfoDisplayPartsEnum3" {
    const content =
        \\enum /*1*/E {
        \\    /*2*/"e1",
        \\    /*3*/'e2' = 10,
        \\    /*4*/"e3"
        \\}
        \\var /*5*/eInstance: /*6*/E;
        \\/*7*/eInstance = /*8*/E[/*9*/"e1"];
        \\/*10*/eInstance = /*11*/E[/*12*/"e2"];
        \\/*13*/eInstance = /*14*/E[/*15*/'e3'];
        \\const enum /*16*/constE {
        \\    /*17*/"e1",
        \\    /*18*/'e2' = 10,
        \\    /*19*/"e3"
        \\}
        \\var /*20*/eInstance1: /*21*/constE;
        \\/*22*/eInstance1 = /*23*/constE[/*24*/"e1"];
        \\/*25*/eInstance1 = /*26*/constE[/*27*/"e2"];
        \\/*28*/eInstance1 = /*29*/constE[/*30*/'e3'];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestCodeFixClassImplementInterfaceMemberOrdering" {
    const content =
        \\// @lib: es2017
        \\/** asdf */
        \\interface I {
        \\    1;
        \\    2;
        \\    3;
        \\    4;
        \\    5;
        \\    6;
        \\    7;
        \\    8;
        \\    9;
        \\    10;
        \\    11;
        \\    12;
        \\    13;
        \\    14;
        \\    15;
        \\    16;
        \\    17;
        \\    18;
        \\    19;
        \\    20;
        \\    21;
        \\    22;
        \\    /** a nice safe prime */
        \\    23;
        \\}
        \\class C implements I {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'I'",
        .NewFileContent = "/** asdf */\ninterface I {\n    1;\n    2;\n    3;\n    4;\n    5;\n    6;\n    7;\n    8;\n    9;\n    10;\n    11;\n    12;\n    13;\n    14;\n    15;\n    16;\n    17;\n    18;\n    19;\n    20;\n    21;\n    22;\n    /** a nice safe prime */\n    23;\n}\nclass C implements I {\n    1: any;\n    2: any;\n    3: any;\n    4: any;\n    5: any;\n    6: any;\n    7: any;\n    8: any;\n    9: any;\n    10: any;\n    11: any;\n    12: any;\n    13: any;\n    14: any;\n    15: any;\n    16: any;\n    17: any;\n    18: any;\n    19: any;\n    20: any;\n    21: any;\n    22: any;\n    23: any;\n}",
        .Index = 0,
    });
}

test "TestTsxRename7" {
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
        \\interface OptionPropBag {
        \\    [|[|{| "contextRangeIndex": 0 |}propx|]: number|]
        \\    propString: string
        \\    optional?: boolean
        \\}
        \\declare function Opt(attributes: OptionPropBag): JSX.Element;
        \\let opt = <Opt />;
        \\let opt1 = <Opt [|[|{| "contextRangeIndex": 2 |}propx|]={100}|] propString />;
        \\let opt2 = <Opt [|[|{| "contextRangeIndex": 4 |}propx|]={100}|] optional/>;
        \\let opt3 = <Opt wrong />;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRenameAtRangesWithText(undefined, null , "propx");
}

test "TestQuickInfoJsDocTagsFunctionOverload03" {
    const content =
        \\// @Filename: quickInfoJsDocTagsFunctionOverload03.ts
        \\declare function /*1*/foo(): void;
        \\
        \\/**
        \\ * Doc foo overloaded
        \\ * @tag Tag text
        \\ */
        \\declare function /*2*/foo(x: number): void
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestTripleSlashRefPathCompletionExtensionsAllowJSFalse" {
    const content =
        \\// @Filename: test0.ts
        \\/// <reference path="/*0*/
        \\/// <reference path=".//*1*/
        \\/// <reference path="./f/*2*/
        \\// @Filename: f1.ts
        \\
        \\// @Filename: f1.js
        \\
        \\// @Filename: f1.d.ts
        \\
        \\// @Filename: f1.tsx
        \\
        \\// @Filename: f1.js
        \\
        \\// @Filename: f1.jsx
        \\
        \\// @Filename: f1.cs
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
//                 "f1.d.ts",
//                 "f1.ts",
//                 "f1.tsx",
//             },
//         },
//     });
}

test "TestImportNameCodeFix_fileWithNoTrailingNewline" {
    const content =
        \\// @Filename: /a.ts
        \\export const foo = 0;
        \\// @Filename: /b.ts
        \\export const bar = 0;
        \\// @Filename: /c.ts
        \\foo;
        \\import { bar } from "./b";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/c.ts");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "foo;\nimport { foo } from \"./a\";\nimport { bar } from \"./b\";",
    }, null );
}

test "TestFormattingReplaceTabsWithSpaces" {
    const content =
        \\namespace Foo {
        \\/*1*/                class Test { }
        \\/*2*/            class Test { }
        \\/*3*/class Test { }
        \\/*4*/             class Test { }
        \\/*5*/   class Test { }
        \\/*6*/    class Test { }
        \\/*7*/     class Test { }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyCurrentLineContent(undefined, "    class Test { }");
    _ = f.GoToMarker(undefined, "2");
    _ = f.VerifyCurrentLineContent(undefined, "    class Test { }");
    _ = f.GoToMarker(undefined, "3");
    _ = f.VerifyCurrentLineContent(undefined, "    class Test { }");
    _ = f.GoToMarker(undefined, "4");
    _ = f.VerifyCurrentLineContent(undefined, "    class Test { }");
    _ = f.GoToMarker(undefined, "5");
    _ = f.VerifyCurrentLineContent(undefined, "    class Test { }");
    _ = f.GoToMarker(undefined, "6");
    _ = f.VerifyCurrentLineContent(undefined, "    class Test { }");
    _ = f.GoToMarker(undefined, "7");
    _ = f.VerifyCurrentLineContent(undefined, "    class Test { }");
}

test "TestCommentsLinePreservation" {
    const content =
        \\/** This is firstLine
        \\  * This is second Line
        \\  * 
        \\  * This is fourth Line
        \\  */
        \\var /*a*/a: string;
        \\/** 
        \\  * This is firstLine
        \\  * This is second Line
        \\  * 
        \\  * This is fourth Line
        \\  */
        \\var /*b*/b: string;
        \\/** 
        \\  * This is firstLine
        \\  * This is second Line
        \\  * 
        \\  * This is fourth Line
        \\  *
        \\  */
        \\var /*c*/c: string;
        \\/** 
        \\  * This is firstLine
        \\  * This is second Line
        \\  * @param param
        \\  * @random tag This should be third line
        \\  */
        \\function /*d*/d(param: string) { /*1*/param = "hello"; }
        \\/** 
        \\  * This is firstLine
        \\  * This is second Line
        \\  * @param param
        \\  */
        \\function /*e*/e(param: string) { /*2*/param = "hello"; }
        \\/** 
        \\  * This is firstLine
        \\  * This is second Line
        \\  * @param param1 first line of param
        \\  *
        \\  *  param information third line
        \\  * @random tag This should be third line
        \\  */
        \\function /*f*/f(param1: string) { /*3*/param1 = "hello"; }
        \\/** 
        \\  * This is firstLine
        \\  * This is second Line
        \\  * @param param1
        \\  *
        \\  *  param information first line
        \\  * @random tag This should be third line
        \\  */
        \\function /*g*/g(param1: string) { /*4*/param1 = "hello"; }
        \\/** 
        \\  * This is firstLine
        \\  * This is second Line
        \\  * @param param1
        \\  *
        \\  *  param information first line
        \\  *
        \\  *  param information third line
        \\  * @random tag This should be third line
        \\  */
        \\function /*h*/h(param1: string) { /*5*/param1 = "hello"; }
        \\/** 
        \\  * This is firstLine
        \\  * This is second Line
        \\  * @param param1
        \\  *
        \\  *  param information first line
        \\  *
        \\  *  param information third line
        \\  *
        \\  */
        \\function /*i*/i(param1: string) { /*6*/param1 = "hello"; }
        \\/** 
        \\  * This is firstLine
        \\  * This is second Line
        \\  * @param param1
        \\  *
        \\  *  param information first line
        \\  *
        \\  *  param information third line
        \\  */
        \\function /*j*/j(param1: string) { /*7*/param1 = "hello"; }
        \\/** 
        \\  * This is firstLine
        \\  * This is second Line
        \\  * @param param1 hello   @randomtag 
        \\  *
        \\  *  random information first line
        \\  *
        \\  *  random information third line
        \\  */
        \\function /*k*/k(param1: string) { /*8*/param1 = "hello"; }
        \\/** 
        \\  * This is firstLine
        \\  * This is second Line
        \\  * @param param1 first Line text
        \\  *
        \\  * @param param1 
        \\  *
        \\  * blank line that shouldnt be shown when starting this 
        \\  * second time information about the param again
        \\  */
        \\function /*l*/l(param1: string) { /*9*/param1 = "hello"; }
        \\     /** 
        \\       * This is firstLine
        \\ This is second Line
        \\ [1]: third * line
        \\ @param param1 first Line text
        \\ second line text
        \\ */
        \\function /*m*/m(param1: string) { /*10*/param1 = "hello"; }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "a", "var a: string", "This is firstLine\nThis is second Line\n\nThis is fourth Line");
    // f.VerifyQuickInfoAt(undefined, "b", "var b: string", "This is firstLine\nThis is second Line\n\nThis is fourth Line");
    // f.VerifyQuickInfoAt(undefined, "c", "var c: string", "This is firstLine\nThis is second Line\n\nThis is fourth Line");
    // f.VerifyQuickInfoAt(undefined, "d", "function d(param: string): void", "This is firstLine\nThis is second Line");
    // f.VerifyQuickInfoAt(undefined, "1", "(parameter) param: string", "");
    // f.VerifyQuickInfoAt(undefined, "e", "function e(param: string): void", "This is firstLine\nThis is second Line");
    // f.VerifyQuickInfoAt(undefined, "2", "(parameter) param: string", "");
    // f.VerifyQuickInfoAt(undefined, "f", "function f(param1: string): void", "This is firstLine\nThis is second Line");
    // f.VerifyQuickInfoAt(undefined, "3", "(parameter) param1: string", "first line of param\n\nparam information third line");
    // f.VerifyQuickInfoAt(undefined, "g", "function g(param1: string): void", "This is firstLine\nThis is second Line");
    // f.VerifyQuickInfoAt(undefined, "4", "(parameter) param1: string", " param information first line");
    // f.VerifyQuickInfoAt(undefined, "h", "function h(param1: string): void", "This is firstLine\nThis is second Line");
    // f.VerifyQuickInfoAt(undefined, "5", "(parameter) param1: string", " param information first line\n\n param information third line");
    // f.VerifyQuickInfoAt(undefined, "i", "function i(param1: string): void", "This is firstLine\nThis is second Line");
    // f.VerifyQuickInfoAt(undefined, "6", "(parameter) param1: string", " param information first line\n\n param information third line");
    // f.VerifyQuickInfoAt(undefined, "j", "function j(param1: string): void", "This is firstLine\nThis is second Line");
    // f.VerifyQuickInfoAt(undefined, "7", "(parameter) param1: string", " param information first line\n\n param information third line");
    // f.VerifyQuickInfoAt(undefined, "k", "function k(param1: string): void", "This is firstLine\nThis is second Line");
    // f.VerifyQuickInfoAt(undefined, "8", "(parameter) param1: string", "hello");
    // f.VerifyQuickInfoAt(undefined, "l", "function l(param1: string): void", "This is firstLine\nThis is second Line");
    // f.VerifyQuickInfoAt(undefined, "9", "(parameter) param1: string", "first Line text\nblank line that shouldnt be shown when starting this \nsecond time information about the param again");
    // f.VerifyQuickInfoAt(undefined, "m", "function m(param1: string): void", "This is firstLine\nThis is second Line\n[1]: third * line");
    // f.VerifyQuickInfoAt(undefined, "10", "(parameter) param1: string", "first Line text\nsecond line text");
}

test "TestCompletionForStringLiteral_quotePreference8" {
    const content =
        \\// @filename: /a.ts
        \\export const a = null;
        \\// @filename: /b.ts
        \\import { a } from './a';
        \\
        \\const foo = { '"a name\'s all good but it\'s better with more"': null };
        \\foo[|./**/|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/b.ts");
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =      "\"a name's all good but it's better with more\"",
//                     .InsertText = undefined("['\"a name\\'s all good but it\\'s better with more\"']"),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "\"a name's all good but it's better with more\"",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//         .UserPreferences = &.{.QuotePreference = lsutil.QuotePreference("auto")},
//     });
}

test "TestFormattingEqualsBeforeBracketInTypeAlias" {
    const content =
        \\type X    =     [number]/*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, ";");
    _ = f.VerifyCurrentLineContent(undefined, "type X = [number];");
}

test "TestChainedFatArrowFormatting" {
    const content =
        \\var fn = () => () => null/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, ";");
    _ = f.VerifyCurrentLineContent(undefined, "var fn = () => () => null;");
}

test "TestCompletionForObjectProperty" {
    const content =
        \\// @Filename: /a.ts
        \\export const foo = { bar: 'baz' };
        \\// @Filename: /b.ts
        \\const test = foo/*1*/
        \\// @Filename: /c.ts
        \\const test2 = {...foo/*2*/}
        \\// @Filename: /d.ts
        \\const test3 = [{...foo/*3*/}]
        \\// @Filename: /e.ts
        \\const test4 = { foo/*4*/ }
        \\// @Filename: /f.ts
        \\const test5 = { foo: /*5*/ }
        \\// @Filename: /g.ts
        \\const test6 = { unrelated: foo/*6*/ }
        \\// @Filename: /i.ts
        \\const test7: { foo/*7*/: "unrelated" }
        \\// @Filename: /h.ts
        \\const test8: { foo: string } = { foo/*8*/ }
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
//                 &.{
//                     .Label = "foo",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./a",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
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
//                     .Label = "foo",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./a",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
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
//                     .Label = "foo",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./a",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "4", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label = "foo",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./a",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
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
//                     .Label = "foo",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./a",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
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
//                     .Label = "foo",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./a",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "7", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Excludes = &.{
//                 "foo",
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
//             .Includes = &.{
//                 &.{
//                     .Label =    "foo",
//                     .SortText = undefined(string(ls.SortTextLocationPriority)),
//                 },
//             },
//         },
//     });
}

test "TestGoToDefinitionSignatureAlias" {
    const content =
        \\// @jsx: preserve
        \\// @Filename: /a.tsx
        \\function /*f*/f() {}
        \\const /*g*/g = f;
        \\const /*h*/h = g;
        \\[|/*useF*/f|]();
        \\[|/*useG*/g|]();
        \\[|/*useH*/h|]();
        \\const /*i*/i = () => 0;
        \\const /*iFn*/iFn = function () { return 0; };
        \\const /*j*/j = i;
        \\[|/*useI*/i|]();
        \\[|/*useIFn*/iFn|]();
        \\[|/*useJ*/j|]();
        \\const o = { /*m*/m: () => 0 };
        \\o.[|/*useM*/m|]();
        \\const oFn = { /*mFn*/mFn: function () { return 0; } };
        \\oFn.[|/*useMFn*/mFn|]();
        \\class Component { /*componentCtr*/constructor(props: {}) {} }
        \\type ComponentClass = /*ComponentClass*/new () => Component;
        \\interface ComponentClass2 { /*ComponentClass2*/new(): Component; }
        \\
        \\class /*MyComponent*/MyComponent extends Component {}
        \\<[|/*jsxMyComponent*/MyComponent|] />;
        \\new [|/*newMyComponent*/MyComponent|]({});
        \\
        \\declare const /*MyComponent2*/MyComponent2: ComponentClass;
        \\<[|/*jsxMyComponent2*/MyComponent2|] />;
        \\new [|/*newMyComponent2*/MyComponent2|]();
        \\
        \\declare const /*MyComponent3*/MyComponent3: ComponentClass2;
        \\<[|/*jsxMyComponent3*/MyComponent3|] />;
        \\new [|/*newMyComponent3*/MyComponent3|]();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
    // f.VerifyBaselineGoToDefinition(undefined, true, "useF", "useG", "useH", "useI", "useIFn", "useJ", "useM", "useMFn", "jsxMyComponent", "newMyComponent", "jsxMyComponent2", "newMyComponent2", "jsxMyComponent3", "newMyComponent3");
}

test "TestCompletionDetailsOfContextSensitiveParameterNoCrash" {
    const content =
        \\// @strict: true
        \\type __ = never;
        \\
        \\interface CurriedFunction1<T1, R> {
        \\    (): CurriedFunction1<T1, R>;
        \\    (t1: T1): R;
        \\}
        \\interface CurriedFunction2<T1, T2, R> {
        \\    (): CurriedFunction2<T1, T2, R>;
        \\    (t1: T1): CurriedFunction1<T2, R>;
        \\    (t1: __, t2: T2): CurriedFunction1<T1, R>;
        \\    (t1: T1, t2: T2): R;
        \\}
        \\
        \\interface CurriedFunction3<T1, T2, T3, R> {
        \\    (): CurriedFunction3<T1, T2, T3, R>;
        \\    (t1: T1): CurriedFunction2<T2, T3, R>;
        \\    (t1: __, t2: T2): CurriedFunction2<T1, T3, R>;
        \\    (t1: T1, t2: T2): CurriedFunction1<T3, R>;
        \\    (t1: __, t2: __, t3: T3): CurriedFunction2<T1, T2, R>;
        \\    (t1: T1, t2: __, t3: T3): CurriedFunction1<T2, R>;
        \\    (t1: __, t2: T2, t3: T3): CurriedFunction1<T1, R>;
        \\    (t1: T1, t2: T2, t3: T3): R;
        \\}
        \\
        \\interface CurriedFunction4<T1, T2, T3, T4, R> {
        \\    (): CurriedFunction4<T1, T2, T3, T4, R>;
        \\    (t1: T1): CurriedFunction3<T2, T3, T4, R>;
        \\    (t1: __, t2: T2): CurriedFunction3<T1, T3, T4, R>;
        \\    (t1: T1, t2: T2): CurriedFunction2<T3, T4, R>;
        \\    (t1: __, t2: __, t3: T3): CurriedFunction3<T1, T2, T4, R>;
        \\    (t1: __, t2: __, t3: T3): CurriedFunction2<T2, T4, R>;
        \\    (t1: __, t2: T2, t3: T3): CurriedFunction2<T1, T4, R>;
        \\    (t1: T1, t2: T2, t3: T3): CurriedFunction1<T4, R>;
        \\    (t1: __, t2: __, t3: __, t4: T4): CurriedFunction3<T1, T2, T3, R>;
        \\    (t1: T1, t2: __, t3: __, t4: T4): CurriedFunction2<T2, T3, R>;
        \\    (t1: __, t2: T2, t3: __, t4: T4): CurriedFunction2<T1, T3, R>;
        \\    (t1: __, t2: __, t3: T3, t4: T4): CurriedFunction2<T1, T2, R>;
        \\    (t1: T1, t2: T2, t3: __, t4: T4): CurriedFunction1<T3, R>;
        \\    (t1: T1, t2: __, t3: T3, t4: T4): CurriedFunction1<T2, R>;
        \\    (t1: __, t2: T2, t3: T3, t4: T4): CurriedFunction1<T1, R>;
        \\    (t1: T1, t2: T2, t3: T3, t4: T4): R;
        \\}
        \\
        \\declare var curry: {
        \\    <T1, R>(func: (t1: T1) => R, arity?: number): CurriedFunction1<T1, R>;    
        \\    <T1, T2, R>(func: (t1: T1, t2: T2) => R, arity?: number): CurriedFunction2<T1, T2, R>;
        \\    <T1, T2, T3, R>(func: (t1: T1, t2: T2, t3: T3) => R, arity?: number): CurriedFunction3<T1, T2, T3, R>;
        \\    <T1, T2, T3, T4, R>(func: (t1: T1, t2: T2, t3: T3, t4: T4) => R, arity?: number): CurriedFunction4<T1, T2, T3, T4, R>;
        \\    (func: (...args: any[]) => any, arity?: number): (...args: any[]) => any;
        \\    placeholder: __;
        \\};
        \\
        \\export type StylingFunction = (
        \\    keys: (string | false | undefined) | (string | false | undefined)[],
        \\    ...rest: unknown[]
        \\) => object;
        \\
        \\declare const getStylingByKeys: (
        \\    mergedStyling: object,
        \\    keys: (string | false | undefined) | (string | false | undefined)[],
        \\    ...args: unknown[]
        \\) => object;
        \\
        \\declare var mergedStyling: object;
        \\
        \\export const createStyling: CurriedFunction3<
        \\    (base16Theme: object) => unknown,
        \\    object | undefined,
        \\    object | undefined,
        \\    StylingFunction
        \\> = curry<
        \\    (base16Theme: object) => unknown,
        \\    object | undefined,
        \\    object | undefined,
        \\    StylingFunction
        \\>(
        \\    (
        \\        getStylingFromBase16: (base16Theme: object) => unknown,
        \\        options: object = {},
        \\        themeOrStyling: object = {},
        \\        ...args
        \\    ): StylingFunction => {
        \\        return curry(getStylingByKeys, 2)(mergedStyling, .../**/args);
        \\    },
        \\    3
        \\);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestFormatJsxWithKeywordInIdentifier" {
    const content =
        \\// @Filename: /a.tsx
        \\<div module-layout=""></div>
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.VerifyCurrentFileContent(undefined, "<div module-layout=\"\"></div>");
}

test "TestAddFunctionAboveMultiLineLambdaExpression" {
    const content =
        \\/**/
        \\() =>
        \\   // do something
        \\0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, "function Foo() { }");
}

test "TestFormatImportDeclaration" {
    const content =
        \\namespace Foo {/*1*/
        \\}/*2*/
        \\
        \\import bar  =    Foo;/*3*/
        \\
        \\import bar2=Foo;/*4*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyCurrentLineContent(undefined, "namespace Foo {");
    _ = f.GoToMarker(undefined, "2");
    _ = f.VerifyCurrentLineContent(undefined, "}");
    _ = f.GoToMarker(undefined, "3");
    _ = f.VerifyCurrentLineContent(undefined, "import bar = Foo;");
    _ = f.GoToMarker(undefined, "4");
    _ = f.VerifyCurrentLineContent(undefined, "import bar2 = Foo;");
}

test "TestQuickInfoOnObjectLiteralWithAccessors" {
    const content =
        \\function /*1*/makePoint(x: number) {
        \\    return {
        \\        b: 10,
        \\        get x() { return x; },
        \\        set x(a: number) { this.b = a; }
        \\    };
        \\};
        \\var /*4*/point = makePoint(2);
        \\var /*2*/x = point.x;
        \\point./*3*/x = 30;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "function makePoint(x: number): {\n    b: number;\n    x: number;\n}", "");
    // f.VerifyQuickInfoAt(undefined, "2", "var x: number", "");
    // f.VerifyQuickInfoAt(undefined, "3", "(property) x: number", "");
    // f.VerifyQuickInfoAt(undefined, "4", "var point: {\n    b: number;\n    x: number;\n}", "");
    // f.VerifyCompletions(undefined, "3", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =  "b",
//                     .Detail = undefined("(property) b: number"),
//                 },
//                 &.{
//                     .Label =  "x",
//                     .Detail = undefined("(property) x: number"),
//                 },
//             },
//         },
//     });
}

test "TestAutoImportPackageJsonImports_capsInPath1" {
    const content =
        \\// @module: node18
        \\// @Filename: /Dev/package.json
        \\{
        \\  "imports": {
        \\    "#thing": "./src/something.js"
        \\  }
        \\}
        \\// @Filename: /Dev/src/something.ts
        \\export function something(name: string): any;
        \\// @Filename: /Dev/a.ts
        \\something/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"#thing"}, null );
}

test "TestGoToTypeDefinition_promiseType" {
    const content =
        \\// @lib: es5,es2015.promise
        \\type User = { name: string };
        \\async function /*reference*/getUser() { return { name: "Bob" } satisfies User as User }
        \\
        \\const /*reference2*/promisedBob = getUser() 
        \\
        \\export {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToTypeDefinition(undefined, "reference", "reference2");
}

test "TestHighlightsForExportFromUnfoundModule" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\import foo from 'unfound';
        \\export {
        \\  foo,
        \\};
        \\// @Filename: b.js
        \\export {
        \\   /**/foo
        \\} from './a';
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // f.VerifyBaselineRename(undefined, null , "");
}

test "TestRenameExportCrash" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: Foo.js
        \\let a;
        \\module.exports = /**/a;
        \\exports["foo"] = a;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRename(undefined, null , "");
}

test "TestRenameJsSpecialAssignmentRhs1" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\const foo = {
        \\    set: function (x) {
        \\        this._x = x;
        \\    },
        \\    copy: function ([|x|]) {
        \\        this._x = [|x|].prop;
        \\    }
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRename(undefined, null );
}

test "TestGoToDefinitionJsxCall" {
    const content =
        \\// @filename: ./test.tsx
        \\interface FC<P = {}> {
        \\    (props: P, context?: any): string;
        \\}
        \\
        \\const Thing: FC = (props) => <div></div>;
        \\const HelloWorld = () => <[|/**/Thing|] />;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "");
}

test "TestCompletionsImport_named_namespaceImportExists" {
    const content =
        \\// @Filename: /a.ts
        \\export function foo() {}
        \\// @Filename: /b.ts
        \\import * as a from "./a";
        \\f/**/;
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
//                             .ModuleSpecifier = "./a",
//                         },
//                     },
//                     .Detail =              undefined("function foo(): void"),
//                     .Kind =                undefined(lsproto.CompletionItemKindFunction),
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
    // f.VerifyApplyCodeActionFromCompletion(undefined, undefined(""), &.{
//         .Name =        "foo",
//         .Source =      "./a",
//         .Description = "Change 'foo' to 'a.foo'",
//         .NewFileContent = undefined("import * as a from \"./a\";\na.f;"),
//     });
}

test "TestSyntacticClassificationsConflictDiff3Markers2" {
    const content =
        \\<<<<<<< HEAD
        \\class C { }
        \\||||||| merged common ancestors
        \\class E { }
        \\=======
        \\class D { }
        \\>>>>>>> Branch - a
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "class.declaration", .Text = "C"},
//     });
}

test "TestFindReferencesJSXTagName2" {
    const content =
        \\// @Filename: index.tsx
        \\/*1*/const /*2*/obj = {Component: () => <div/>};
        \\const element = </*3*/obj.Component/>;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestReferencesForClassMembersExtendingAbstractClass" {
    const content =
        \\abstract class Base {
        \\    abstract /*a1*/a: number;
        \\    abstract /*method1*/method(): void;
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

test "TestGetEditsForFileRename_notAffectedByJsFile" {
    const content =
        \\// @Filename: /a.ts
        \\export const x = 0;
        \\// @Filename: /a.js
        \\exports.x = 0;
        \\// @Filename: /b.ts
        \\import { x } from "./a";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyWillRenameFilesEdits(undefined, "/a.ts", "/a2.ts", .{
//         .@"/b.ts" = "import { x } from \"./a2\";",
//     }, null );
}

test "TestNavigationBarItemsSymbols1" {
    const content =
        \\class C {
        \\    [Symbol.isRegExp] = 0;
        \\    [Symbol.iterator]() { }
        \\    get [Symbol.isConcatSpreadable]() { }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestAutoImportsNodeNext1" {
    const content =
        \\// @module: node18
        \\// @Filename: /node_modules/pack/package.json
        \\{
        \\    "name": "pack",
        \\    "version": "1.0.0",
        \\    "exports": {
        \\        ".": "./main.mjs"
        \\    }
        \\}
        \\// @Filename: /node_modules/pack/main.d.mts
        \\import {} from "./unreachable.mjs";
        \\export const fromMain = 0;
        \\// @Filename: /node_modules/pack/unreachable.d.mts
        \\export const fromUnreachable = 0;
        \\// @Filename: /index.mts
        \\import { fromMain } from "pack";
        \\fromUnreachable/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyImportFixAtPosition(undefined, &.{}, null );
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Excludes = &.{
//                 "fromUnreachable",
//             },
//         },
//     });
}

test "TestCompletionsAsserts" {
    const content =
        \\declare function assert(argument1: any): asserts a/**/
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
//                     .Label = "argument1",
//                 },
//             },
//         },
//     });
}

test "TestAutoImportPackageJsonImportsPreference2" {
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
    // f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"./src/a/b/c/something"}, &.{.ImportModuleSpecifierPreference = "project-relative"});
}

test "TestSyntacticClassificationsForOfKeyword2" {
    const content =
        \\for (var of in of) { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "variable.declaration", .Text = "of"},
//         .{.Type = "variable", .Text = "of"},
//     });
}

test "TestFindAllRefsWithShorthandPropertyAssignment2" {
    const content =
        \\var /*0*/dx = "Foo";
        \\
        \\namespace M { export var /*1*/dx; }
        \\namespace M {
        \\   var z = 100;
        \\   export var y = { /*2*/dx, z };
        \\}
        \\M.y./*3*/dx;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "0", "1", "2", "3");
}

test "TestCompletionsWithDeprecatedTag5" {
    const content =
        \\// @lib: es5
        \\class Foo {
        \\    /** @deprecated m */
        \\    static m() {}
        \\}
        \\Foo./**/
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
//             .Exact = CompletionFunctionMembersPlus(
//                 &.{
//                     &.{
//                         .Label =    "prototype",
//                         .SortText = undefined(string(ls.SortTextLocationPriority)),
//                     },
//                     &.{
//                         .Label =    "m",
//                         .Kind =     undefined(lsproto.CompletionItemKindMethod),
//                         .SortText = undefined(string(ls.DeprecateSortText(ls.SortTextLocalDeclarationPriority))),
//                         .Tags =     &&.{lsproto.CompletionItemTagDeprecated},
//                     },
//                 },
//             ),
//         },
//     });
}

test "TestCompletionsLiteralDirectlyInRestConstrainedToArrayType" {
    const content =
        \\// @strict: true
        \\
        \\function fn<T extends ('value1' | 'value2' | 'value3')[]>(...values: T): T { return values; }
        \\
        \\const value1 = fn('/*1*/');
        \\const value2 = fn('value1', '/*2*/');
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
//                 "value1",
//                 "value2",
//                 "value3",
//             },
//         },
//     });
}

test "TestCodeFixCorrectReturnValue4" {
    const content =
        \\function Foo (): any {
        \\    1
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCodeFixNotAvailable(undefined);
}

test "TestQuickInfoFromEmptyBlockComment" {
    const content =
        \\/**/
        \\class Foo {
        \\}
        \\var f/*A*/ff = new Foo();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "A", "var fff: Foo", "");
}

test "TestDocumentHighlights_40082" {
    const content =
        \\// @checkJs: true
        \\export = (state, messages) => {
        \\   export [|default|] {
        \\   }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , f.Ranges()[0]);
}

test "TestCompletionListOnAliases2" {
    const content =
        \\// @lib: es5
        \\namespace M {
        \\    export interface I { }
        \\    export class C {
        \\        static property;
        \\    }
        \\    export enum E {
        \\        value = 0
        \\    }
        \\    export namespace N {
        \\        export var v;
        \\    }
        \\    export var V = 0;
        \\    export function F() { }
        \\    export import A = M;
        \\}
        \\
        \\import m = M;
        \\import c = M.C;
        \\import e = M.E;
        \\import n = M.N;
        \\import v = M.V;
        \\import f = M.F;
        \\import a = M.A;
        \\
        \\m./*1*/;
        \\var tmp: m./*1Type*/;
        \\c./*2*/;
        \\e./*3*/;
        \\n./*4*/;
        \\v./*5*/;
        \\f./*6*/;
        \\a./*7*/;
        \\var tmp2: a./*7Type*/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"1", "7"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Unsorted = &.{
//                 "F",
//                 "C",
//                 "E",
//                 "N",
//                 "V",
//                 "A",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"1Type", "7Type"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Unsorted = &.{
//                 "I",
//                 "C",
//                 "E",
//                 "A",
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
//             .Exact = CompletionFunctionMembersPlus(
//                 &.{
//                     &.{
//                         .Label =    "property",
//                         .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                     },
//                     &.{
//                         .Label =    "prototype",
//                         .SortText = undefined(string(ls.SortTextLocationPriority)),
//                     },
//                 },
//             ),
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
//                 "value",
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
//                 "v",
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
//                 "toFixed",
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
//                 "call",
//             },
//         },
//     });
}

test "TestJsdocDeprecated_suggestion3" {
    const content =
        \\// merges
        \\/** @deprecated */
        \\interface a { a: number }
        \\declare function a(): void
        \\declare const ta: [|a|]
        \\a;
        \\a();
        \\interface b { a: number; }
        \\/** @deprecated */
        \\declare function b(): void
        \\declare const tb: b;
        \\[|b|]
        \\[|b|]();
        \\interface c { }
        \\/** @deprecated */
        \\declare function c(): void
        \\declare function c(a: number): void
        \\declare const tc: c;
        \\c;
        \\[|c|]();
        \\c(1);
        \\/** @deprecated */
        \\interface d { }
        \\declare function d(): void
        \\declare function d(a: number): void
        \\declare const td: [|d|];
        \\d;
        \\d();
        \\d(1);
        \\/** @deprecated */
        \\declare function e(): void
        \\/** @deprecated */
        \\declare function e(a: number): void
        \\[|e|];
        \\[|e|]();
        \\[|e|](1);
        \\/** @deprecated */
        \\interface f { a: number }
        \\declare const tf: [|f|]
        \\/** @deprecated */
        \\type g = number
        \\declare const tg: [|g|]
        \\/** @deprecated */
        \\class H { }
        \\declare const th: [|H|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifySuggestionDiagnostics(undefined, []*.{
//         .{
//             .Message = .{.String = undefined("'a' is deprecated.")},
//             .Code =    &.{.Integer = undefined(int32(6385))},
//             .Range =   f.Ranges()[0].LSRange,
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//         },
//         .{
//             .Message = .{.String = undefined("'b' is deprecated.")},
//             .Code =    &.{.Integer = undefined(int32(6385))},
//             .Range =   f.Ranges()[1].LSRange,
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//         },
//         .{
//             .Message = .{.String = undefined("The signature '(): void' of 'b' is deprecated.")},
//             .Code =    &.{.Integer = undefined(int32(6387))},
//             .Range =   f.Ranges()[2].LSRange,
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//         },
//         .{
//             .Message = .{.String = undefined("The signature '(): void' of 'c' is deprecated.")},
//             .Code =    &.{.Integer = undefined(int32(6387))},
//             .Range =   f.Ranges()[3].LSRange,
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//         },
//         .{
//             .Message = .{.String = undefined("'d' is deprecated.")},
//             .Code =    &.{.Integer = undefined(int32(6385))},
//             .Range =   f.Ranges()[4].LSRange,
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//         },
//         .{
//             .Message = .{.String = undefined("'e' is deprecated.")},
//             .Code =    &.{.Integer = undefined(int32(6385))},
//             .Range =   f.Ranges()[5].LSRange,
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//         },
//         .{
//             .Message = .{.String = undefined("The signature '(): void' of 'e' is deprecated.")},
//             .Code =    &.{.Integer = undefined(int32(6387))},
//             .Range =   f.Ranges()[6].LSRange,
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//         },
//         .{
//             .Message = .{.String = undefined("The signature '(a: number): void' of 'e' is deprecated.")},
//             .Code =    &.{.Integer = undefined(int32(6387))},
//             .Range =   f.Ranges()[7].LSRange,
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//         },
//         .{
//             .Message = .{.String = undefined("'f' is deprecated.")},
//             .Code =    &.{.Integer = undefined(int32(6385))},
//             .Range =   f.Ranges()[8].LSRange,
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//         },
//         .{
//             .Message = .{.String = undefined("'g' is deprecated.")},
//             .Code =    &.{.Integer = undefined(int32(6385))},
//             .Range =   f.Ranges()[9].LSRange,
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//         },
//         .{
//             .Message = .{.String = undefined("'H' is deprecated.")},
//             .Code =    &.{.Integer = undefined(int32(6385))},
//             .Range =   f.Ranges()[10].LSRange,
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//         },
//     });
}

test "TestJavaScriptModules19" {
    const content =
        \\// @allowJs: true
        \\// @Filename: myMod.js
        \\var x = { a: 10 };
        \\module.exports = x;
        \\// @Filename: isGlobal.js
        \\var y = 10;
        \\// @Filename: consumer.js
        \\var x = require('./myMod');
        \\/**/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "consumer.js");
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
//                     .Label =    "y",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//             .Excludes = &.{
//                 "invisible",
//             },
//         },
//     });
    _ = f.Insert(undefined, "x.");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label = "a",
//                     .Kind =  undefined(lsproto.CompletionItemKindField),
//                 },
//             },
//         },
//     });
    _ = f.Insert(undefined, "a.");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label = "toFixed",
//                     .Kind =  undefined(lsproto.CompletionItemKindMethod),
//                 },
//             },
//         },
//     });
}

test "TestReferencesForExportedValues" {
    const content =
        \\namespace M {
        \\    /*1*/export var /*2*/variable = 0;
        \\
        \\    // local use
        \\    var x = /*3*/variable;
        \\}
        \\
        \\// external use
        \\M./*4*/variable
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestFindAllRefsWithLeadingUnderscoreNames3" {
    const content =
        \\class Foo {
        \\    /*1*/public /*2*/___bar() { return 0; }
        \\}
        \\
        \\var x: Foo;
        \\x./*3*/___bar;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestQuickInfoOfGenericTypeAssertions1" {
    const content =
        \\function f<T>(x: T): T { return null; }
        \\var /*1*/r = <T>(x: T) => x;
        \\var /*2*/r2 = < <T>(x: T) => T>f;
        \\var a;
        \\var /*3*/r3 = < <T>(x: <A>(y: A) => A) => T>a;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "var r: <T>(x: T) => T", "");
    // f.VerifyQuickInfoAt(undefined, "2", "var r2: <T>(x: T) => T", "");
    // f.VerifyQuickInfoAt(undefined, "3", "var r3: <T>(x: <A>(y: A) => A) => T", "");
}

test "TestTsxCompletionNonTagLessThan" {
    const content =
        \\// @lib: es5
        \\// @Filename: /a.tsx
        \\var x: Array<numb/*a*/;
        \\[].map<numb/*b*/;
        \\1 < Infini/*c*/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"a", "b"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =    "number",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//             .Excludes = &.{
//                 "SVGNumber",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "c", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =    "Infinity",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestNavigationBarMerging" {
    const content =
        \\// @Filename: file1.ts
        \\namespace a {
        \\    function foo() {}
        \\}
        \\namespace b {
        \\    function foo() {}
        \\}
        \\namespace a {
        \\    function bar() {}
        \\}
        \\// @Filename: file2.ts
        \\namespace a {}
        \\function a() {}
        \\// @Filename: file3.ts
        \\namespace a {
        \\    interface A {
        \\        foo: number;
        \\    }
        \\}
        \\namespace a {
        \\    interface A {
        \\        bar: number;
        \\    }
        \\}
        \\// @Filename: file4.ts
        \\namespace A { export var x; }
        \\namespace A.B { export var y; }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineDocumentSymbol(undefined);
    _ = f.GoToFile(undefined, "file2.ts");
    _ = f.VerifyBaselineDocumentSymbol(undefined);
    _ = f.GoToFile(undefined, "file3.ts");
    _ = f.VerifyBaselineDocumentSymbol(undefined);
    _ = f.GoToFile(undefined, "file4.ts");
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestRenameStringLiteralTypes3" {
    const content =
        \\type Foo = "[|a|]" | "b";
        \\
        \\class C {
        \\    p: Foo = "[|a|]";
        \\    m() {
        \\        switch (this.p) {
        \\            case "[|a|]":
        \\                return 1;
        \\            case "b":
        \\                return 2;
        \\        }
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRenameAtRangesWithText(undefined, null , "a");
}

test "TestCompletionsObjectLiteralUnionStringMappingType" {
    const content =
        \\type UnionType = {
        \\  key1: string;
        \\} | {
        \\  key2: number;
        \\} | Uppercase<string>;
        \\
        \\const obj1: UnionType = {
        \\  /*1*/
        \\};
        \\
        \\const obj2: UnionType = {
        \\  key1: "abc",
        \\  /*2*/
        \\};
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
//                     .Label = "key1",
//                 },
//                 &.{
//                     .Label = "key2",
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
//                     .Label = "key2",
//                 },
//             },
//         },
//     });
}

test "TestGoToDefinitionExternalModuleName9" {
    const content =
        \\// @Filename: b.ts
        \\export * from [|'e/*1*/'|];
        \\// @Filename: a.ts
        \\declare module /*2*/"e" {
        \\    class Foo { }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestGetJavaScriptSyntacticDiagnostics16" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\function F(p?) { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineNonSuggestionDiagnostics(undefined);
}

test "TestGetOutliningSpansDepthElseIf" {
    const content =
        \\if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else if (1)[| {
        \\    1;
        \\}|] else[| {
        \\    1;
        \\}|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOutliningSpans(undefined);
}

test "TestClassExtendsInterfaceSigHelp1" {
    const content =
        \\class C {
        \\    public foo(x: string);
        \\    public foo(x: number);
        \\    public foo(x: any) { return x; }
        \\}
        \\interface I extends C {
        \\    other(x: any): any;
        \\}
        \\var i: I;
        \\i.foo(/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // f.VerifySignatureHelp(undefined, .{.ParameterSpan = "x: string", .OverloadsCount = 2});
}

test "TestCompletionAmbientPropertyDeclaration" {
    const content =
        \\class C {
        \\    /*1*/ declare property: number;
        \\    /*2*/
        \\}
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
//             .Exact = CompletionClassElementKeywords,
//         },
//     });
    // f.VerifyCompletions(undefined, "2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionClassElementKeywords,
//         },
//     });
}

test "TestCompletionsWithOverride1" {
    const content =
        \\class A {
        \\    foo () {} 
        \\    bar () {}
        \\}
        \\class B extends A {
        \\    override /*1*/
        \\}
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
//                 "foo",
//                 "bar",
//             },
//         },
//     });
}

test "TestQuickinfoVerbosityMappedType" {
    const content =
        \\type Apple = boolean | number;
        \\type Orange = string | boolean;
        \\type F<T> = {
        \\    [K in keyof T as T[K] extends Apple ? never : K]: T[K];
        \\}
        \\type Bar = {
        \\    banana: string;
        \\    apple: boolean;
        \\}
        \\const x/*x*/: F/*F*/<Bar> = { banana: 'hello' };
        \\const y/*y*/: { [K in keyof Bar]?: Bar[K] } = { banana: 'hello' };
        \\type G<T> = {
        \\    [K in keyof T]: T[K] & Apple
        \\};
        \\const z: G/*G*/<Bar> = { banana: 'hello', apple: true };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"x" = .{0, 1}, .@"y" = .{0}, .@"F" = .{0, 1}, .@"G" = .{0, 1}});
}

test "TestQuickInfoJsDocTags9" {
    const content =
        \\// @noEmit: true
        \\// @allowJs: true
        \\// @Filename: quickInfoJsDocTags9.js
        \\/**
        \\ * @typedef {{ [x: string]: any, y: number }} Foo
        \\ */
        \\
        \\/**
        \\ * @type {(t: T) => number}
        \\ * @template {Foo} T Comment Text
        \\ */
        \\const /**/foo = t => t.y;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestTsxFindAllReferences1" {
    const content =
        \\//@Filename: file.tsx
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\        /*1*/div: {
        \\            name?: string;
        \\            isOpen?: boolean;
        \\        };
        \\        span: { n: string; };
        \\    }
        \\}
        \\var x = /*2*/</*3*/div />;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestFindAllRefsForDefaultExport08" {
    const content =
        \\export default class DefaultExportedClass {
        \\}
        \\
        \\var x: DefaultExportedClass;
        \\
        \\var y = new DefaultExportedClass;
        \\
        \\namespace /*1*/DefaultExportedClass {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
    // f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestGoToDefinitionMethodOverloads" {
    const content =
        \\class MethodOverload {
        \\    static [|/*staticMethodOverload1*/method|]();
        \\    static /*staticMethodOverload2*/method(foo: string);
        \\    static /*staticMethodDefinition*/method(foo?: any) { }
        \\    public [|/*instanceMethodOverload1*/method|](): any;
        \\    public /*instanceMethodOverload2*/method(foo: string);
        \\    public /*instanceMethodDefinition*/method(foo?: any) { return "foo" }
        \\}
        \\// static method
        \\MethodOverload.[|/*staticMethodReference1*/method|]();
        \\MethodOverload.[|/*staticMethodReference2*/method|]("123");
        \\// instance method
        \\var methodOverload = new MethodOverload();
        \\methodOverload.[|/*instanceMethodReference1*/method|]();
        \\methodOverload.[|/*instanceMethodReference2*/method|]("456");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "staticMethodReference1", "staticMethodReference2", "instanceMethodReference1", "instanceMethodReference2", "staticMethodOverload1", "instanceMethodOverload1");
}

test "TestSignatureHelpCommentsFunctionExpression" {
    const content =
        \\/** lambdaFoo var comment*/
        \\var lambdaFoo = /** this is lambda comment*/ (/**param a*/a: number, /**param b*/b: number) => a + b;
        \\var lambddaNoVarComment = /** this is lambda multiplication*/ (/**param a*/a: number, /**param b*/b: number) => a * b;
        \\lambdaFoo(/*5*/10, /*6*/20);
        \\function anotherFunc(a: number) {
        \\    /** documentation
        \\        @param b {string} inner parameter */
        \\    var lambdaVar = /** inner docs */(b: string) => {
        \\        var localVar = "Hello ";
        \\        return localVar + b;
        \\    }
        \\    return lambdaVar("World") + a;
        \\}
        \\/**
        \\ * On variable
        \\ * @param s the first parameter!
        \\ * @returns the parameter's length
        \\ */
        \\var assigned = /**
        \\                * Summary on expression
        \\                * @param s param on expression
        \\                * @returns return on expression
        \\                */function(/** On parameter */s: string) {
        \\  return s.length;
        \\}
        \\assigned(/*18*/"hey");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineSignatureHelp(undefined);
}

test "TestAutoImportCompletionExportListAugmentation3" {
    const content =
        \\// @module: node18
        \\// @Filename: /node_modules/@sapphire/pieces/index.d.ts
        \\export interface Container {
        \\  stores: unknown;
        \\}
        \\
        \\declare class Piece {
        \\  container: Container;
        \\}
        \\
        \\export { Piece };
        \\// @FileName: /augmentation.ts
        \\declare module "@sapphire/pieces" {
        \\  interface Container {
        \\    client: unknown;
        \\  }
        \\}
        \\// @Filename: /index.ts
        \\import { Piece } from "@sapphire/pieces";
        \\class FullPiece extends Piece {
        \\  /*1*/
        \\}
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
//                 &.{
//                     .Label =               "container",
//                     .InsertText =          undefined("container: Container;"),
//                     .FilterText =          undefined("container"),
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .Data = &.{
//                         .Source = "ClassMemberSnippet/",
//                     },
//                 },
//             },
//         },
//     });
    // f.VerifyApplyCodeActionFromCompletion(undefined, undefined("1"), &.{
//         .Name =        "container",
//         .Source =      "ClassMemberSnippet/",
//         .Description = "Includes imports of types referenced by 'container'",
//         .NewFileContent = undefined("import { Container, Piece } from \"@sapphire/pieces\";\nclass FullPiece extends Piece {\n  \n}"),
//     });
}

test "TestQuickInfoDisplayPartsFunctionExpression" {
    const content =
        \\var /*1*/x = function /*2*/foo() {
        \\    /*3*/foo();
        \\};
        \\var /*4*/y = function () {
        \\};
        \\(function /*5*/foo1() {
        \\    /*6*/foo1();
        \\})();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestJsDocFunctionSignatures11" {
    const content =
        \\// @allowJs: true
        \\// @Filename: Foo.js
        \\/**
        \\ * @type {{ [name: string]: string; }} variables
        \\ */
        \\const vari/**/ables = {};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyQuickInfoIs(undefined, "const variables: {\n    [name: string]: string;\n}", "");
}

test "TestThisPredicateFunctionCompletions02" {
    const content =
        \\interface Sundries {
        \\    broken: boolean;
        \\}
        \\
        \\interface Supplies {
        \\    spoiled: boolean;
        \\}
        \\
        \\interface Crate<T> {
        \\    contents: T;
        \\    isSundries(): this is Crate<Sundries>;
        \\    isSupplies(): this is Crate<Supplies>;
        \\    isPackedTight(): this is (this & {extraContents: T});
        \\}
        \\const crate: Crate<any>;
        \\if (crate.isPackedTight()) {
        \\    crate./*1*/;
        \\}
        \\if (crate.isSundries()) {
        \\    crate.contents./*2*/;
        \\    if (crate.isPackedTight()) {
        \\        crate./*3*/;
        \\    }
        \\}
        \\if (crate.isSupplies()) {
        \\    crate.contents./*4*/;
        \\    if (crate.isPackedTight()) {
        \\        crate./*5*/;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"1", "3", "5"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "contents",
//                 "extraContents",
//                 "isPackedTight",
//                 "isSundries",
//                 "isSupplies",
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
//                 "broken",
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
//                 "spoiled",
//             },
//         },
//     });
}

test "TestFindAllRefsInheritedProperties4" {
    const content =
        \\interface C extends D {
        \\    /*0*/prop0: string;
        \\    /*1*/prop1: number;
        \\}
        \\
        \\interface D extends C {
        \\    /*2*/prop0: string;
        \\}
        \\
        \\var d: D;
        \\d./*3*/prop0;
        \\d./*4*/prop1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "0", "2", "3", "1", "4");
}

test "TestDocCommentTemplateInterfacePropertyFunctionType" {
    const content =
        \\interface I {
        \\    /**/
        \\    foo: (a: number, b: string) => void;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyJSDocCompletion(undefined, "", 11, "/**\n     * \n     * @param a\n     * @param b\n     * @returns\n     */", null);
    // f.VerifyJSDocCompletion(undefined, "", 11, "/**\n     * \n     * @param a\n     * @param b\n     */", undefined(false));
}

test "TestCompletionListInUnclosedDeleteExpression01" {
    const content =
        \\var x;
        \\var y = delete /*1*/
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
//             },
//         },
//     });
}

test "TestSmartSelection_JSDocTags4" {
    const content =
        \\/**
        \\ * @typedef {object} Foo
        \\ * @property {string} a
        \\ * @property {number} b
        \\ * @property {/**/number} c
        \\ */
        \\
        \\/** @type {Foo} */
        \\const foo;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineSelectionRanges(undefined);
}

test "TestJsdocThrowsTag_findAllReferences" {
    const content =
        \\class /**/E extends Error {}
        \\/**
        \\ * @throws {E}
        \\ */
        \\function f() {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "");
}

test "TestGoToDefinitionVariableAssignment1" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @filename: foo.js
        \\const Foo = module./*def*/exports = function () {}
        \\Foo.prototype.bar = function() {}
        \\new [|Foo/*ref*/|]();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "foo.js");
    // f.VerifyBaselineGoToDefinition(undefined, true, "ref");
}

test "TestGotoDefinitionLinkTag3" {
    const content =
        \\// @Filename: /a.ts
        \\enum E {
        \\    /** {@link /*1*/[|Foo|]} */
        \\    Foo
        \\}
        \\interface [|/*2*/Foo|] {
        \\    foo: E.Foo;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, false, "1");
}

test "TestGoToDefinitionOverriddenMember18" {
    const content =
        \\// @strict: true
        \\// @target: esnext
        \\// @lib: esnext
        \\const entityKind = Symbol.for("drizzle:entityKind");
        \\
        \\abstract class MySqlColumn {
        \\  readonly /*2*/[entityKind]: string = "MySqlColumn";
        \\}
        \\
        \\export class MySqlVarBinary extends MySqlColumn {
        \\  [|/*1*/override|] readonly [entityKind]: string = "MySqlVarBinary";
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestCompletionListInExtendsClause" {
    const content =
        \\// @lib: es5
        \\interface IFoo {
        \\    method();
        \\}
        \\
        \\class Foo {
        \\    property: number;
        \\    method() { }
        \\    static staticMethod() { }
        \\}
        \\class test1 extends Foo./*1*/ {}
        \\class test2 implements IFoo./*2*/ {}
        \\interface test3 extends IFoo./*3*/ {}
        \\interface test4 implements Foo./*4*/ {}
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
//             .Exact = CompletionFunctionMembersPlus(
//                 &.{
//                     &.{
//                         .Label =    "staticMethod",
//                         .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                     },
//                     &.{
//                         .Label =    "prototype",
//                         .SortText = undefined(string(ls.SortTextLocationPriority)),
//                     },
//                 },
//             ),
//         },
//     });
    _ = f.VerifyCompletions(undefined, &.{"2", "3", "4"}, null);
}

test "TestCompletionsPropertiesPriorities" {
    const content =
        \\// @strict: true
        \\interface I {
        \\  B?: number;
        \\  a: number;
        \\  c?: string;
        \\  d: string
        \\}
        \\const foo = {
        \\  a: 1,
        \\  B: 2
        \\}
        \\const i: I = {
        \\  ...foo,
        \\  /*a*/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"a"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =    "d",
//                     .SortText = undefined(string(ls.SortTextLocationPriority)),
//                     .Kind =     undefined(lsproto.CompletionItemKindField),
//                 },
//                 &.{
//                     .Label =      "c?",
//                     .InsertText = undefined("c"),
//                     .FilterText = undefined("c"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                     .Kind =       undefined(lsproto.CompletionItemKindField),
//                 },
//                 &.{
//                     .Label =    "a",
//                     .SortText = undefined(string(ls.SortTextMemberDeclaredBySpreadAssignment)),
//                     .Kind =     undefined(lsproto.CompletionItemKindField),
//                 },
//                 &.{
//                     .Label =      "B?",
//                     .InsertText = undefined("B"),
//                     .FilterText = undefined("B"),
//                     .SortText =   undefined(string(ls.SortTextMemberDeclaredBySpreadAssignment)),
//                     .Kind =       undefined(lsproto.CompletionItemKindField),
//                 },
//             },
//         },
//     });
}

test "TestCodeFixAddMissingConstToArrayDestructuring3" {
    const content =
        \\let x: any;
        \\[x, y] = [0, 1];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCodeFixNotAvailable(undefined);
}

test "TestGetOccurrencesOfAnonymousFunction" {
    const content =
        \\(function [|foo|](): number {
        \\    var x = [|foo|];
        \\    return 0;
        \\})
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestCodeFixClassImplementInterface_quotePreferenceAuto1" {
    const content =
        \\// @filename: a.ts
        \\export interface I {
        \\    a(): void;
        \\    b(x: "x", y: "a" | "b"): "b";
        \\
        \\    c: "c";
        \\    d: { e: "e"; };
        \\}
        \\// @filename: b.ts
        \\import { I } from "./a";
        \\class Foo implements I {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "b.ts");
    // f.VerifyCodeFix(undefined, .{
//         .Description = "Implement interface 'I'",
//         .NewFileContent = "import { I } from \"./a\";\nclass Foo implements I {\n    a(): void {\n        throw new Error(\"Method not implemented.\");\n    }\n    b(x: \"x\", y: \"a\" | \"b\"): \"b\" {\n        throw new Error(\"Method not implemented.\");\n    }\n    c: \"c\";\n    d: { e: \"e\"; };\n}",
//         .Index =           0,
//         .UserPreferences = &.{.QuotePreference = lsutil.QuotePreference("auto")},
//     });
}

test "TestCodeFixMissingTypeAnnotationOnExports4" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\const a = 42;
        \\const b = 42;
        \\export class C {
        \\  method() { return a + b };
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFixAvailable(undefined, &.{"Add return type 'number'"});
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Add return type 'number'",
        .NewFileContent = "const a = 42;\nconst b = 42;\nexport class C {\n  method(): number { return a + b };\n}",
        .Index = 0,
    });
}

test "TestUnusedImports5FS" {
    const content =
        \\// @noUnusedLocals: true
        \\// @Filename: file2.ts
        \\[| import {Calculator, test, test2} from "./file1" |]
        \\
        \\var x = new Calculator();
        \\x.handleChar();
        \\test();
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
    _ = f.VerifyRangeAfterCodeFix(undefined, "import {Calculator, test} from \"./file1\"", false, 0, 0);
}

test "TestCompletionListEnumValues" {
    const content =
        \\enum Colors {
        \\    Red,
        \\    Green
        \\}
        \\
        \\Colors./*enumVariable*/;
        \\
        \\var x = Colors.Red;
        \\x./*variableOfEnumType*/;
        \\
        \\function foo(): Colors { return null; }
        \\foo()./*callOfEnumReturnType*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "enumVariable", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "Green",
//                 "Red",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"variableOfEnumType", "callOfEnumReturnType"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "toExponential",
//                 "toFixed",
//                 "toLocaleString",
//                 "toPrecision",
//                 "toString",
//                 "valueOf",
//             },
//         },
//     });
}

test "TestRenameForDefaultExport08" {
    const content =
        \\// @Filename: foo.ts
        \\export default function DefaultExportedFunction() {
        \\    return /**/[|DefaultExportedFunction|]
        \\}
        \\/**
        \\ *  Commenting DefaultExportedFunction
        \\ */
        \\
        \\var x: typeof DefaultExportedFunction;
        \\
        \\var y = DefaultExportedFunction();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyRenameSucceeded(undefined, null );
}

test "TestInlayHintsInteractiveFunctionParameterTypes4" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: /a.js
        \\class Foo {
        \\    #value = 0;
        \\    get foo() { return this.#value; }
        \\    /**
        \\     * @param {number} value
        \\     */
        \\    set foo(value) { this.#value = value; }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayFunctionParameterTypeHints = core.TSTrue}});
}

test "TestFindAllRefsOnDefinition2" {
    const content =
        \\//@Filename: findAllRefsOnDefinition2-import.ts
        \\export module Test{
        \\
        \\    /*1*/export interface /*2*/start { }
        \\
        \\    export interface stop { }
        \\}
        \\//@Filename: findAllRefsOnDefinition2.ts
        \\import Second = require("./findAllRefsOnDefinition2-import");
        \\
        \\var start: Second.Test./*3*/start;
        \\var stop: Second.Test.stop;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestQuickInfoGenerics" {
    const content =
        \\class Con/*1*/tainer<T> {
        \\    x: T;
        \\}
        \\interface IList</*2*/T> {
        \\    getItem(i: number): /*3*/T;
        \\}
        \\class List2</*4*/T extends IList<number>> implements IList<T> {
        \\    private __it/*6*/em: /*5*/T[];
        \\    public get/*7*/Item(i: number) {
        \\        return this.__item[i];
        \\    }
        \\    public /*8*/method</*9*/S extends IList<T>>(s: S, p: /*10*/T[]) {
        \\        return s;
        \\    }
        \\}
        \\function foo4</*11*/T extends Date>(test: T): T;
        \\function foo4</*12*/S extends string>(test: S): S;
        \\function foo4(test: any): any;
        \\function foo4</*13*/T extends Date>(test: any): any { return null; }
        \\var x: List2<IList<number>>;
        \\var y = x./*14*/getItem(10);
        \\var x2: IList<IList<number>>;
        \\var x3: IList<number>;
        \\var y2 = x./*15*/method(x2, [x3, x3]);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "class Container<T>", "");
    // f.VerifyQuickInfoAt(undefined, "2", "(type parameter) T in IList<T>", "");
    // f.VerifyQuickInfoAt(undefined, "3", "(type parameter) T in IList<T>", "");
    // f.VerifyQuickInfoAt(undefined, "4", "(type parameter) T in List2<T extends IList<number>>", "");
    // f.VerifyQuickInfoAt(undefined, "5", "(type parameter) T in List2<T extends IList<number>>", "");
    // f.VerifyQuickInfoAt(undefined, "6", "(property) List2<T extends IList<number>>.__item: T[]", "");
    // f.VerifyQuickInfoAt(undefined, "7", "(method) List2<T extends IList<number>>.getItem(i: number): T", "");
    // f.VerifyQuickInfoAt(undefined, "8", "(method) List2<T extends IList<number>>.method<S extends IList<T>>(s: S, p: T[]): S", "");
    // f.VerifyQuickInfoAt(undefined, "9", "(type parameter) S in List2<T extends IList<number>>.method<S extends IList<T>>(s: S, p: T[]): S", "");
    // f.VerifyQuickInfoAt(undefined, "10", "(type parameter) T in List2<T extends IList<number>>", "");
    // f.VerifyQuickInfoAt(undefined, "11", "(type parameter) T in foo4<T extends Date>(test: T): T", "");
    // f.VerifyQuickInfoAt(undefined, "12", "(type parameter) S in foo4<S extends string>(test: S): S", "");
    // f.VerifyQuickInfoAt(undefined, "13", "(type parameter) T in foo4<T extends Date>(test: any): any", "");
    // f.VerifyQuickInfoAt(undefined, "14", "(method) List2<IList<number>>.getItem(i: number): IList<number>", "");
    // f.VerifyQuickInfoAt(undefined, "15", "(method) List2<IList<number>>.method<IList<IList<number>>>(s: IList<IList<number>>, p: IList<number>[]): IList<IList<number>>", "");
}

test "TestJsdocReturnsTag" {
    const content =
        \\// @allowJs: true
        \\// @Filename: dummy.js
        \\/**
        \\ * Find an item
        \\ * @template T
        \\ * @param {T[]} l
        \\ * @param {T} x
        \\ * @returns {?T}  The names of the found item(s).
        \\ */
        \\function find(l, x) {
        \\}
        \\find(''/**/);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineSignatureHelp(undefined);
}

test "TestGoToDefinitionImport1" {
    const content =
        \\// @Filename: /b.ts
        \\/*2*/export const foo = 1;
        \\// @Filename: /a.ts
        \\import { foo } from      [|"./b/*1*/"|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestImportNameCodeFix_quoteStyle" {
    const content =
        \\// @Filename: /a.ts
        \\export const foo: number;
        \\// @Filename: /b.ts
        \\[|foo;|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/b.ts");
    // f.VerifyImportFixAtPosition(undefined, &.{
//         "import { foo } from './a';\n\nfoo;",
//     }, &.{.QuotePreference = lsutil.QuotePreference("single")});
}

test "TestCompletionListStaticProtectedMembers2" {
    const content =
        \\// @target: es2015
        \\// @lib: es5
        \\class Base {
        \\    private static privateMethod() { }
        \\    private static privateProperty;
        \\
        \\    protected static protectedMethod() { }
        \\    protected static protectedProperty;
        \\
        \\    public static publicMethod() { }
        \\    public static publicProperty;
        \\
        \\    protected static protectedOverriddenMethod() { }
        \\    protected static protectedOverriddenProperty;
        \\}
        \\
        \\class C2 extends Base {
        \\    protected static protectedOverriddenMethod() { }
        \\    protected static protectedOverriddenProperty;
        \\
        \\    static test() {
        \\        Base./*1*/;
        \\        C2./*2*/;
        \\        this./*3*/;
        \\        super./*4*/;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"1"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionFunctionMembersPlus(
//                 &.{
//                     &.{
//                         .Label =    "protectedMethod",
//                         .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                     },
//                     &.{
//                         .Label =    "protectedOverriddenMethod",
//                         .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                     },
//                     &.{
//                         .Label =    "protectedOverriddenProperty",
//                         .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                     },
//                     &.{
//                         .Label =    "protectedProperty",
//                         .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                     },
//                     &.{
//                         .Label =    "publicMethod",
//                         .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                     },
//                     &.{
//                         .Label =    "publicProperty",
//                         .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                     },
//                     &.{
//                         .Label =    "prototype",
//                         .SortText = undefined(string(ls.SortTextLocationPriority)),
//                     },
//                 },
//             ),
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"2", "3"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionFunctionMembersPlus(
//                 &.{
//                     &.{
//                         .Label =    "protectedMethod",
//                         .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                     },
//                     &.{
//                         .Label =    "protectedOverriddenMethod",
//                         .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                     },
//                     &.{
//                         .Label =    "protectedOverriddenProperty",
//                         .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                     },
//                     &.{
//                         .Label =    "protectedProperty",
//                         .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                     },
//                     &.{
//                         .Label =    "publicMethod",
//                         .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                     },
//                     &.{
//                         .Label =    "publicProperty",
//                         .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                     },
//                     &.{
//                         .Label =    "test",
//                         .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                     },
//                     &.{
//                         .Label =    "prototype",
//                         .SortText = undefined(string(ls.SortTextLocationPriority)),
//                     },
//                 },
//             ),
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
//                     .Label =    "protectedMethod",
//                     .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                 },
//                 &.{
//                     .Label =    "protectedOverriddenMethod",
//                     .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                 },
//                 &.{
//                     .Label =    "protectedOverriddenProperty",
//                     .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                 },
//                 &.{
//                     .Label =    "protectedProperty",
//                     .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                 },
//                 &.{
//                     .Label =    "publicMethod",
//                     .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                 },
//                 &.{
//                     .Label =    "publicProperty",
//                     .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                 },
//                 &.{
//                     .Label =    "apply",
//                     .SortText = undefined(string(ls.SortTextLocationPriority)),
//                 },
//                 &.{
//                     .Label =    "arguments",
//                     .SortText = undefined(string(ls.SortTextLocationPriority)),
//                 },
//                 &.{
//                     .Label =    "bind",
//                     .SortText = undefined(string(ls.SortTextLocationPriority)),
//                 },
//                 &.{
//                     .Label =    "call",
//                     .SortText = undefined(string(ls.SortTextLocationPriority)),
//                 },
//                 &.{
//                     .Label =    "caller",
//                     .SortText = undefined(string(ls.SortTextLocationPriority)),
//                 },
//                 &.{
//                     .Label =    "length",
//                     .SortText = undefined(string(ls.SortTextLocationPriority)),
//                 },
//                 &.{
//                     .Label =    "prototype",
//                     .SortText = undefined(string(ls.SortTextLocationPriority)),
//                 },
//                 &.{
//                     .Label =    "toString",
//                     .SortText = undefined(string(ls.SortTextLocationPriority)),
//                 },
//             },
//         },
//     });
}

test "TestCompletionListInUnclosedFunction12" {
    const content =
        \\interface MyType {
        \\}
        \\
        \\function foo(x: string, y: number, z: boolean) {
        \\    function bar(a: number, b: string = "hello", c: typeof x = "hello") {
        \\        var v = (p: /*1*/
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
//                 "MyType",
//             },
//         },
//     });
}

test "TestCodeFixAddMissingEnumMember13" {
    const content =
        \\enum E { A, B }
        \\declare var a: E;
        \\a.C;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCodeFixNotAvailable(undefined, "fixMissingMember");
}

test "TestAutoImportCrossProject_paths_stripSrc" {
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
        \\      "dep/*": ["../dep/src/*"]
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
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { dep1 } from \"dep\";\n\ndep1;",
    }, null );
    _ = f.GoToMarker(undefined, "2");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { dep2 } from \"dep/sub/folder\";\n\ndep2;",
    }, null );
}

test "TestCompletionListInUnclosedFunction19" {
    const content =
        \\interface MyType {
        \\}
        \\
        \\function foo(x: string, y: number, z: boolean) {
        \\    function bar(a: number, b: string = "hello", c: typeof x = "hello") {
        \\        var v = (p: MyType) => { return y + /*1*/
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
//                 "b",
//                 "c",
//                 "v",
//                 "p",
//             },
//         },
//     });
}

test "TestCompletionOfAwaitPromise7" {
    const content =
        \\async function foo(x: Promise<string>) {
        \\    console.log
        \\    [|x./**/|]
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
//             .Includes = &.{
//                 "then",
//                 &.{
//                     .Label =      "trim",
//                     .InsertText = undefined(";(await x).trim"),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "trim",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestCodeFixMissingTypeAnnotationOnExports6" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\function foo(): number[] { return [42]; }
        \\export const c = [...foo()];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Add annotation of type 'number[]'",
        .NewFileContent = "function foo(): number[] { return [42]; }\nexport const c: number[] = [...foo()];",
        .Index = 0,
    });
}

test "TestCodefixCrashExportGlobal" {
    const content =
        \\// @module: commonjs
        \\// @esModuleInterop: false
        \\// @allowSyntheticDefaultImports: false
        \\// @Filename: bar.ts
        \\import * as foo from './foo'
        \\export as namespace foo
        \\export = foo;
        \\
        \\declare global {
        \\    const foo: typeof foo;
        \\}
        \\// @Filename: foo.d.ts
        \\interface Root {
        \\    /**
        \\     * A .default property for ES6 default import compatibility
        \\     */
        \\    default: Root;
        \\}
        \\
        \\declare const root: Root;
        \\export = root;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "bar.ts");
    // f.VerifyCodeFixNotAvailable(undefined);
    _ = f.GoToFile(undefined, "foo.d.ts");
    // f.VerifyCodeFixNotAvailable(undefined);
}

test "TestContextualTypingGenericFunction1" {
    const content =
        \\var obj: { f<T>(x: T): T } = { f: <S>(/*1*/x) => x };
        \\var obj2: <T>(x: T) => T = <S>(/*2*/x) => x;
        \\
        \\class C<T> {
        \\    obj: <T>(x: T) => T
        \\}
        \\var c = new C();
        \\c.obj = <S>(/*3*/x) => x;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "(parameter) x: any", "");
    // f.VerifyQuickInfoAt(undefined, "2", "(parameter) x: any", "");
    // f.VerifyQuickInfoAt(undefined, "3", "(parameter) x: any", "");
}

test "TestCompletionListForTransitivelyExportedMembers01" {
    const content =
        \\// @Filename: A.ts
        \\export interface I1 { one: number }
        \\export interface I2 { two: string }
        \\export type I1_OR_I2 = I1 | I2;
        \\
        \\export class C1 {
        \\    one: string;
        \\}
        \\
        \\export namespace Inner {
        \\    export interface I3 {
        \\        three: boolean
        \\    }
        \\
        \\    export var varVar = 100;
        \\    export let letVar = 200;
        \\    export const constVar = 300;
        \\}
        \\// @Filename: B.ts
        \\export var bVar = "bee!";
        \\// @Filename: C.ts
        \\export var cVar = "see!";
        \\export * from "./A";
        \\export * from "./B"
        \\// @Filename: D.ts
        \\import * as c from "./C";
        \\var x = c./**/
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
//                 "bVar",
//                 "C1",
//                 "cVar",
//                 "Inner",
//             },
//         },
//     });
}

test "TestUnusedVariableInClass5" {
    const content =
        \\// @noUnusedLocals: true
        \\// @target: esnext
        \\declare class greeter {
        \\    #private;
        \\    private name;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
}

test "TestGetJavaScriptCompletions1" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: Foo.js
        \\/** @type {number} */
        \\var v;
        \\v./**/
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
//                     .Label = "toExponential",
//                     .Kind =  undefined(lsproto.CompletionItemKindMethod),
//                 },
//             },
//         },
//     });
}

test "TestJsxAttributeCompletionStyleBraces" {
    const content =
        \\// @Filename: foo.tsx
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\        foo: {
        \\            prop_a: boolean;
        \\            prop_b: string;
        \\            prop_c: any;
        \\            prop_d: { p1: string; }
        \\            prop_e: string | undefined;
        \\            prop_f: boolean | undefined | { p1: string; };
        \\            prop_g: { p1: string; } | undefined;
        \\            prop_h?: string;
        \\            prop_i?: boolean;
        \\            prop_j?: { p1: string; };
        \\        }
        \\    }
        \\}
        \\
        \\<foo [|prop_/**/|] />
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
//                     .Label =            "prop_a",
//                     .InsertText =       undefined("prop_a={$1}"),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                 },
//                 &.{
//                     .Label =            "prop_b",
//                     .InsertText =       undefined("prop_b={$1}"),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                 },
//                 &.{
//                     .Label =            "prop_c",
//                     .InsertText =       undefined("prop_c={$1}"),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                 },
//                 &.{
//                     .Label =            "prop_d",
//                     .InsertText =       undefined("prop_d={$1}"),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                 },
//                 &.{
//                     .Label =            "prop_e",
//                     .InsertText =       undefined("prop_e={$1}"),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                 },
//                 &.{
//                     .Label =            "prop_f",
//                     .InsertText =       undefined("prop_f={$1}"),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                 },
//                 &.{
//                     .Label =            "prop_g",
//                     .InsertText =       undefined("prop_g={$1}"),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                 },
//                 &.{
//                     .Label =            "prop_h?",
//                     .InsertText =       undefined("prop_h={$1}"),
//                     .FilterText =       undefined("prop_h"),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                     .SortText =         undefined(string(ls.SortTextOptionalMember)),
//                 },
//                 &.{
//                     .Label =            "prop_i?",
//                     .InsertText =       undefined("prop_i={$1}"),
//                     .FilterText =       undefined("prop_i"),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                     .SortText =         undefined(string(ls.SortTextOptionalMember)),
//                 },
//                 &.{
//                     .Label =            "prop_j?",
//                     .InsertText =       undefined("prop_j={$1}"),
//                     .FilterText =       undefined("prop_j"),
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                     .SortText =         undefined(string(ls.SortTextOptionalMember)),
//                 },
//             },
//         },
//     });
}

test "TestInlayHintsInteractiveImportType2" {
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
    // f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayVariableTypeHints = core.TSTrue, .IncludeInlayFunctionLikeReturnTypeHints = core.TSTrue}});
}

test "TestSemanticClassificationUninstantiatedModuleWithVariableOfSameName2" {
    const content =
        \\module /*0*/M {
        \\    export interface /*1*/I {
        \\    }
        \\}
        \\
        \\var /*2*/M = {
        \\    foo: 10,
        \\    bar: 20
        \\}
        \\
        \\var v: /*3*/M./*4*/I;
        \\
        \\var x = /*5*/M;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "variable", .Text = "M"},
//         .{.Type = "interface.declaration", .Text = "I"},
//         .{.Type = "variable.declaration", .Text = "M"},
//         .{.Type = "property.declaration", .Text = "foo"},
//         .{.Type = "property.declaration", .Text = "bar"},
//         .{.Type = "variable.declaration", .Text = "v"},
//         .{.Type = "variable", .Text = "M"},
//         .{.Type = "interface", .Text = "I"},
//         .{.Type = "variable.declaration", .Text = "x"},
//         .{.Type = "variable", .Text = "M"},
//     });
}

test "TestReferencesForEnums" {
    const content =
        \\enum E {
        \\    /*1*/value1 = 1,
        \\    /*2*/"/*3*/value2" = /*4*/value1,
        \\    /*5*/111 = 11
        \\}
        \\
        \\E./*6*/value1;
        \\E["/*7*/value2"];
        \\E./*8*/value2;
        \\E[/*9*/111];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5", "6", "7", "8", "9");
}

test "TestCompletionsOverridingMethod3" {
    const content =
        \\// @newline: LF
        \\// @Filename: boo.d.ts
        \\interface Ghost {
        \\    boo(): string;
        \\}
        \\
        \\declare class Poltergeist implements Ghost {
        \\    /*b*/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "b", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =      "boo",
//                     .InsertText = undefined("boo(): string;"),
//                     .FilterText = undefined("boo"),
//                     .SortText =   undefined(string(ls.SortTextLocationPriority)),
//                 },
//             },
//         },
//     });
}

test "TestNavigationBarGetterAndSetter" {
    const content =
        \\class X {
        \\    get x() {}
        \\    set x(value) {
        \\        // Inner declaration should make the setter top-level.
        \\        function f() {}
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestGetOccurrencesProtected1" {
    const content =
        \\namespace m {
        \\    export class C1 {
        \\        public pub1;
        \\        public pub2;
        \\        private priv1;
        \\        private priv2;
        \\        [|protected|] prot1;
        \\        [|protected|] prot2;
        \\
        \\        public public;
        \\        private private;
        \\        [|protected|] protected;
        \\
        \\        public constructor(public a, private b, [|protected|] c, public d, private e, [|protected|] f) {
        \\            this.public = 10;
        \\            this.private = 10;
        \\            this.protected = 10;
        \\        }
        \\
        \\        public get x() { return 10; }
        \\        public set x(value) { }
        \\
        \\        public static statPub;
        \\        private static statPriv;
        \\        [|protected|] static statProt;
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
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestQuickInfoJsDocTags15" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @filename: /a.js
        \\/**
        \\ * @callback Bar
        \\ * @param {string} name
        \\ * @returns {string}
        \\ */
        \\
        \\/**
        \\ * @typedef Foo
        \\ * @property {Bar} getName
        \\ */
        \\export const foo = 1;
        \\// @filename: /b.js
        \\import * as _a from "./a.js";
        \\/**
        \\ * @implements {_a.Foo/*1*/}
        \\ */
        \\class C1 { }
        \\
        \\/**
        \\ * @extends {_a.Foo/*2*/}
        \\ */
        \\class C2 { }
        \\
        \\/**
        \\ * @augments {_a.Foo/*3*/}
        \\ */
        \\class C3 { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/b.js");
    _ = f.VerifyBaselineHover(undefined);
}

test "TestCompletionListSuperMembers" {
    const content =
        \\class Base {
        \\    private privateInstanceMethod() { }
        \\    public publicInstanceMethod() { }
        \\
        \\    private privateProperty = 1;
        \\    public publicProperty = 1;
        \\
        \\    private static privateStaticProperty = 1;
        \\    public static publicStaticProperty = 1;
        \\
        \\    private static privateStaticMethod() { }
        \\    public static publicStaticMethod() {
        \\        Class./*staticsInsideClassScope*/publicStaticMethod();
        \\        var c = new Class();
        \\        c./*instanceMembersInsideClassScope*/privateProperty;
        \\    }
        \\}
        \\class Class extends Base {
        \\    private test() {
        \\        super./**/
        \\    }
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
//             .Includes = &.{
//                 "publicInstanceMethod",
//             },
//             .Excludes = &.{
//                 "publicProperty",
//                 "publicStaticProperty",
//                 "publicStaticMethod",
//                 "privateProperty",
//                 "privateInstanceMethod",
//             },
//         },
//     });
}

test "TestCompletionListInObjectBindingPattern12" {
    const content =
        \\interface I {
        \\    property1: number;
        \\    property2: string;
        \\}
        \\
        \\function f({ property1, /**/ }: I): void {
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
//             .Includes = &.{
//                 "property2",
//             },
//             .Excludes = &.{
//                 "property1",
//             },
//         },
//     });
}

test "TestQuickInfoDisplayPartsLet" {
    const content =
        \\let /*1*/a = 10;
        \\function foo() {
        \\    let /*2*/b = /*3*/a;
        \\    if (b) {
        \\        let /*4*/b1 = 10;
        \\    }
        \\}
        \\namespace m {
        \\    let /*5*/c = 10;
        \\    export let /*6*/d = 10;
        \\    if (c) {
        \\        let /*7*/e = 10;
        \\    }
        \\}
        \\let /*8*/f: () => number;
        \\let /*9*/g = /*10*/f;
        \\/*11*/f();
        \\let /*12*/h: { (a: string): number; (a: number): string; };
        \\let /*13*/i = /*14*/h;
        \\/*15*/h(10);
        \\/*16*/h("hello");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestFormattingObjectLiteralOpenCurlyNewlineTyping" {
    const content =
        \\
        \\var varName =/**/
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, "\n{");
    // f.VerifyCurrentFileContent(undefined, "\nvar varName =\n    {\n");
    _ = f.Insert(undefined, "\na: 1");
    _ = f.FormatDocument(undefined, "");
    // f.VerifyCurrentFileContent(undefined, "\nvar varName =\n{\n    a: 1\n");
    _ = f.Insert(undefined, "\n};");
    _ = f.FormatDocument(undefined, "");
    // f.VerifyCurrentFileContent(undefined, "\nvar varName =\n{\n    a: 1\n};\n");
}

test "TestCompletionsPaths_pathMapping_notInNestedDirectory" {
    const content =
        \\// @Filename: /user.ts
        \\import {} from "something//**/";
        \\// @Filename: /tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "baseUrl": ".",
        \\        "paths": {
        \\            "mapping/*": ["whatever"],
        \\        }
        \\    }
        \\}
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
//             .Exact = &.{},
//         },
//     });
}

test "TestCompletionsOverridingProperties2" {
    const content =
        \\interface I {
        \\    prop: string;
        \\}
        \\class C implements I {
        \\    public pr/**/: string = 'foo';
        \\}
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
//             .Includes = &.{
//                 &.{
//                     .Label = "prop",
//                 },
//             },
//         },
//     });
}

test "TestReferencesForExpressionKeywords" {
    const content =
        \\class C {
        \\    static x = 1;
        \\}
        \\/*new*/new C();
        \\/*void*/void C;
        \\/*typeof*/typeof C;
        \\/*delete*/delete C.x;
        \\/*async*/async function* f() {
        \\    /*yield*/yield C;
        \\    /*await*/await C;
        \\}
        \\"x" /*in*/in C;
        \\undefined /*instanceof*/instanceof C;
        \\undefined /*as*/as C;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "new", "void", "typeof", "yield", "await", "in", "instanceof", "as", "delete");
}

test "TestRenameDestructuringAssignmentNestedInArrayLiteral" {
    const content =
        \\interface I {
        \\    [|[|{| "contextRangeIndex": 0 |}property1|]: number;|]
        \\    property2: string;
        \\}
        \\var elems: I[], p1: number, [|[|{| "contextRangeIndex": 2 |}property1|]: number|];
        \\[|[{ [|{| "contextRangeIndex": 4 |}property1|]: p1 }] = elems;|]
        \\[|[{ [|{| "contextRangeIndex": 6 |}property1|] }] = elems;|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRename(undefined, null , f.Ranges()[1], f.Ranges()[5], f.Ranges()[3], f.Ranges()[7]);
}

test "TestCompletionsOverridingMethod9" {
    const content =
        \\// @strict: false
        \\// @Filename: a.ts
        \\// @newline: LF
        \\interface IFoo {
        \\    a?: number;
        \\    b?(x: number): void;
        \\}
        \\class Foo implements IFoo {
        \\    /**/
        \\}
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
//             .Includes = &.{
//                 &.{
//                     .Label =      "a",
//                     .InsertText = undefined("a?: number;"),
//                     .FilterText = undefined("a"),
//                     .SortText =   undefined(string(ls.SortTextLocationPriority)),
//                 },
//                 &.{
//                     .Label =      "b",
//                     .InsertText = undefined("b(x: number): void {\n}"),
//                     .FilterText = undefined("b"),
//                     .SortText =   undefined(string(ls.SortTextLocationPriority)),
//                 },
//             },
//         },
//     });
}

test "TestFormattingIfInElseBlock" {
    const content =
        \\if (true) {
        \\}
        \\else {
        \\    if (true) {
        \\        /*1*/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, "}");
    _ = f.VerifyCurrentLineContent(undefined, "    }");
}

test "TestCodeFixInferFromUsageOptionalParam2" {
    const content =
        \\// @noImplicitAny: true
        \\function f([|a? |]){
        \\    if (a < 9) return;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyRangeAfterCodeFix(undefined, "a?: number", false, 0, 0);
}

test "TestImportNameCodeFixNewImportNodeModules4" {
    const content =
        \\[|f1/*0*/('');|]
        \\// @Filename: package.json
        \\{ "dependencies": { "package-name": "latest" } }
        \\// @Filename: node_modules/package-name/bin/lib/libfile.d.ts
        \\export function f1(text: string): string;
        \\// @Filename: node_modules/package-name/bin/lib/libfile.js
        \\function f1(text) { }
        \\exports.f1 = f1;
        \\// @Filename: node_modules/package-name/package.json
        \\{
        \\  "main": "bin/lib/libfile.js",
        \\  "types": "bin/lib/libfile.d.ts"
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { f1 } from \"package-name\";\n\nf1('');",
    }, null );
}

test "TestRenameDestructuringNestedBindingElement" {
    const content =
        \\interface MultiRobot {
        \\    name: string;
        \\    skills: {
        \\        [|[|{| "contextRangeIndex": 0|}primary|]: string;|]
        \\        secondary: string;
        \\    };
        \\}
        \\let multiRobots: MultiRobot[];
        \\for ([|let { skills: {[|{| "contextRangeIndex": 2|}primary|]: primaryA, secondary: secondaryA } } of multiRobots|]) {
        \\    console.log(primaryA);
        \\}
        \\for ([|let { skills: {[|{| "contextRangeIndex": 4|}primary|], secondary } } of multiRobots|]) {
        \\    console.log([|primary|]);
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRename(undefined, null , f.Ranges()[1], f.Ranges()[3], f.Ranges()[5], f.Ranges()[6]);
}

test "TestFormattingMappedType" {
    const content =
        \\/*generic*/type t  < T  > =   {
        \\/*map*/   [   P   in   keyof    T  ]   :   T  [  P  ]
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "generic");
    _ = f.VerifyCurrentLineContent(undefined, "type t<T> = {");
    _ = f.GoToMarker(undefined, "map");
    _ = f.VerifyCurrentLineContent(undefined, "    [P in keyof T]: T[P]");
}

test "TestJsDocFunctionSignatures7" {
    const content =
        \\// @allowJs: true
        \\// @Filename: Foo.js
        \\/**
        \\ * @param {string} p0
        \\ * @param {string} [p1]
        \\ */
        \\function Test(p0, p1) {
        \\    this.P0 = p0;
        \\    this.P1 = p1;
        \\}
        \\
        \\
        \\var /**/test = new Test("");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyQuickInfoIs(undefined, "var test: Test", "");
}

test "TestJsxAttributeCompletionStyleNone" {
    const content =
        \\// @Filename: foo.tsx
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\        foo: {
        \\            prop_a: boolean;
        \\            prop_b: string;
        \\            prop_c: any;
        \\            prop_d: { p1: string; }
        \\            prop_e: string | undefined;
        \\            prop_f: boolean | undefined | { p1: string; };
        \\            prop_g: { p1: string; } | undefined;
        \\            prop_h?: string;
        \\            prop_i?: boolean;
        \\            prop_j?: { p1: string; };
        \\        }
        \\    }
        \\}
        \\
        \\<foo [|prop_/**/|] />
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
//                     .Label = "prop_a",
//                 },
//                 &.{
//                     .Label = "prop_b",
//                 },
//                 &.{
//                     .Label = "prop_c",
//                 },
//                 &.{
//                     .Label = "prop_d",
//                 },
//                 &.{
//                     .Label = "prop_e",
//                 },
//                 &.{
//                     .Label = "prop_f",
//                 },
//                 &.{
//                     .Label = "prop_g",
//                 },
//                 &.{
//                     .Label =      "prop_h?",
//                     .InsertText = undefined("prop_h"),
//                     .FilterText = undefined("prop_h"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//                 &.{
//                     .Label =      "prop_i?",
//                     .InsertText = undefined("prop_i"),
//                     .FilterText = undefined("prop_i"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//                 &.{
//                     .Label =      "prop_j?",
//                     .InsertText = undefined("prop_j"),
//                     .FilterText = undefined("prop_j"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//             },
//         },
//     });
}

test "TestImportNameCodeFix_sortByDistance" {
    const content =
        \\// @module: commonjs
        \\// @Filename: /src/admin/utils/db/db.ts
        \\export const db = {};
        \\// @Filename: /src/admin/utils/db/index.ts
        \\export * from "./db";
        \\// @Filename: /src/client/helpers/db.ts
        \\export const db = {};
        \\// @Filename: /src/client/db.ts
        \\export const db = {};
        \\// @Filename: /src/client/foo.ts
        \\db/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { db } from \"./db\";\n\ndb",
        "import { db } from \"./helpers/db\";\n\ndb",
        "import { db } from \"../admin/utils/db\";\n\ndb",
        "import { db } from \"../admin/utils/db/db\";\n\ndb",
    }, null );
}

test "TestImportNameCodeFix_order2" {
    const content =
        \\// @Filename: /a.ts
        \\export const _aB: number;
        \\export const _Ab: number;
        \\export const aB: number;
        \\export const Ab: number;
        \\// @Filename: /b.ts
        \\[|import {
        \\    _aB,
        \\    _Ab,
        \\    Ab,
        \\} from "./a";
        \\aB;|]
        \\// @Filename: /c.ts
        \\[|import {
        \\    _aB,
        \\    _Ab,
        \\    Ab,
        \\} from "./a";
        \\aB;|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/b.ts");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import {\n    _aB,\n    _Ab,\n    Ab,\n    aB,\n} from \"./a\";\naB;",
    }, null );
    _ = f.GoToFile(undefined, "/c.ts");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import {\n    _aB,\n    _Ab,\n    aB,\n    Ab,\n} from \"./a\";\naB;",
    }, null );
}

test "TestRenameNoDefaultLib" {
    const content =
        \\// @checkJs: true
        \\// @allowJs: true
        \\// @Filename: /foo.js
        \\// @ts-check
        \\const [|/**/foo|] = 1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyRenameSucceeded(undefined, null );
}

test "TestAutoImportCrossProject_paths_sharedOutDir" {
    const content =
        \\// @Filename: /home/src/workspaces/project/tsconfig.base.json
        \\{
        \\  "compilerOptions": {
        \\    "lib": ["es5"],
        \\    "module": "commonjs",
        \\    "baseUrl": ".",
        \\    "paths": {
        \\      "packages/*": ["./packages/*"]
        \\    }
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/packages/app/tsconfig.json
        \\{
        \\  "extends": "../../tsconfig.base.json",
        \\  "compilerOptions": { "outDir": "../../dist/packages/app" },
        \\  "references": [{ "path": "../dep" }]
        \\}
        \\// @Filename: /home/src/workspaces/project/packages/app/index.ts
        \\dep/**/
        \\// @Filename: /home/src/workspaces/project/packages/app/utils.ts
        \\import "packages/dep";
        \\// @Filename: /home/src/workspaces/project/packages/dep/tsconfig.json
        \\{
        \\  "extends": "../../tsconfig.base.json",
        \\  "compilerOptions": { "outDir": "../../dist/packages/dep" }
        \\}
        \\// @Filename: /home/src/workspaces/project/packages/dep/index.ts
        \\import "./sub/folder";
        \\// @Filename: /home/src/workspaces/project/packages/dep/sub/folder/index.ts
        \\export const dep = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { dep } from \"packages/dep/sub/folder\";\n\ndep",
    }, null );
}

test "TestInheritedModuleMembersForClodule2" {
    const content =
        \\// @strict: false
        \\namespace M {
        \\    export namespace A {
        \\        var o;
        \\    }
        \\}
        \\namespace M {
        \\    export class A { a = 1;}
        \\}
        \\namespace M {
        \\    export class A { /**/b }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyQuickInfoExists(undefined);
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 4);
}

test "TestCompletionForStringLiteralFromSignature2" {
    const content =
        \\declare function f(a: "x"): void;
        \\declare function f(a: string, b: number): void;
        \\f("/**/", 0);
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
//             .Exact = &.{},
//         },
//     });
}

test "TestFindAllRefsMappedType" {
    const content =
        \\interface T { /*1*/a: number; }
        \\type U = { readonly [K in keyof T]?: string };
        \\declare const t: T;
        \\t./*2*/a;
        \\declare const u: U;
        \\u./*3*/a;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestCodeFixClassExtendAbstractPrivateProperty" {
    const content =
        \\// @noImplicitOverride: true
        \\abstract class A {
        \\   private abstract x: number;
        \\   m() { this.x; } // Avoid unused private
        \\}
        \\
        \\class C extends A {[| |]}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCodeFixNotAvailable(undefined);
}

test "TestGetEditsForFileRename_ambientModule" {
    const content =
        \\// @Filename: /tsconfig.json
        \\{}
        \\// @Filename: /sub/types.d.ts
        \\// @Symlink: /node_modules/sub/types.d.ts
        \\declare module "sub" {
        \\    declare export const abc: number
        \\}
        \\// @Filename: /sub/package.json
        \\// @Symlink: /node_modules/sub/package.json
        \\{ "types": "types.d.ts" }
        \\// @Filename: /a.ts
        \\import { abc } from "sub";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyWillRenameFilesEdits(undefined, "/a.ts", "/b.ts", .{}, null );
}

test "TestQuickInfoForObjectBindingElementName02" {
    const content =
        \\interface I {
        \\    property1: number;
        \\    property2: string;
        \\}
        \\
        \\var foo: I;
        \\var { property1: /**/prop1 } = foo;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "var prop1: number", "");
}

test "TestQuickInfoAtPropWithAmbientDeclarationInJs" {
    const content =
        \\// @allowJs: true
        \\// @filename: /a.js
        \\class C {
        \\    constructor() {
        \\        this.prop = "";
        \\    }
        \\    declare prop: string;
        \\    method() {
        \\        this.prop.foo/**/
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestQuickinfoVerbosityClass1" {
    const content =
        \\{
        \\    class Foo {
        \\        a!: "a" | "c";
        \\    }
        \\    const f/*f1*/ = new Foo();
        \\}
        \\{
        \\    type FooParam = "a" | "b";
        \\    class Foo {
        \\        constructor(public x: string) {
        \\            this.x = "a";
        \\        }
        \\        foo(p: FooParam): void {}
        \\    }
        \\    const f/*f2*/ = new Foo("");
        \\}
        \\{
        \\    class Bar/*B*/ {
        \\        a!: string;
        \\        bar(): void {}
        \\        baz(param: string): void {}
        \\    }
        \\    class Foo extends Bar {
        \\        b!: boolean;
        \\        override baz(param: string | number): void {}
        \\    }
        \\    const f/*f3*/ = new Foo();
        \\}
        \\{
        \\    class Bar<B extends string> {
        \\        bar(param: B): void {}
        \\        baz(): this { return this; }
        \\    }
        \\    class Foo extends Bar<"foo"> {
        \\        foo(): this { return this; }
        \\    }
        \\    const b/*b1*/ = new Bar();
        \\    const f/*f4*/ = new Foo();
        \\}
        \\{
        \\    class Bar<B extends string> {
        \\        bar(param: B): void {}
        \\        baz(): this { return this; }
        \\    }
        \\    const noname/*n1*/ = new (class extends Bar<"foo"> {
        \\        foo(): this { return this; }
        \\    })();
        \\    const klass = class extends Bar<"foo"> {
        \\        foo(): this { return this; }
        \\    };
        \\    const k/*k1*/ = new klass();
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"f1" = .{0, 1}, .@"f2" = .{0, 1, 2}, .@"f3" = .{0, 1}, .@"b1" = .{0, 1}, .@"f4" = .{0, 1}, .@"n1" = .{0, 1}, .@"k1" = .{0, 1}, .@"B" = .{0, 1}});
}

test "TestQuickinfoVerbosityServer" {
    const content =
        \\// @lib: es5
        \\type FooType = string | number
        \\const foo/*a*/: FooType = 1
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"a" = .{0, 1}});
}

test "TestImportNameCodeFix_pathsWithoutBaseUrl2" {
    const content =
        \\// @Filename: /packages/test-package-1/tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "module": "commonjs",
        \\    "paths": {
        \\      "test-package-2/*": ["../test-package-2/src/*"]
        \\    }
        \\  }
        \\}
        \\// @Filename: /packages/test-package-1/src/common/logging.ts
        \\export class Logger {};
        \\// @Filename: /packages/test-package-1/src/something/index.ts
        \\Logger/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { Logger } from \"../common/logging\";\n\nLogger",
    }, null );
}

test "TestSignatureHelpTaggedTemplatesNegatives3" {
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

test "TestReferencesForStaticsAndMembersWithSameNames" {
    const content =
        \\namespace FindRef4 {
        \\    namespace MixedStaticsClassTest {
        \\        export class Foo {
        \\            /*1*/bar: Foo;
        \\            /*2*/static /*3*/bar: Foo;
        \\
        \\            /*4*/public /*5*/foo(): void {
        \\            }
        \\            /*6*/public static /*7*/foo(): void {
        \\            }
        \\        }
        \\    }
        \\
        \\    function test() {
        \\        // instance function
        \\        var x = new MixedStaticsClassTest.Foo();
        \\        x./*8*/foo();
        \\        x./*9*/bar;
        \\
        \\        // static function
        \\        MixedStaticsClassTest.Foo./*10*/foo();
        \\        MixedStaticsClassTest.Foo./*11*/bar;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11");
}

test "TestQuickInfoInheritDoc4" {
    const content =
        \\// @Filename: quickInfoInheritDoc4.ts
        \\var A: any;
        \\
        \\class B extends A {
        \\    /**
        \\     * @inheritdoc
        \\     */
        \\    static /**/value() {
        \\        return undefined;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestCodeFixSpelling5" {
    const content =
        \\// @Filename: f1.ts
        \\export const fooooooooo = 1;
        \\// @Filename: f2.ts
        \\import {[|fooooooooa|]} from "./f1"; fooooooooa;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "f2.ts");
    _ = f.VerifyRangeAfterCodeFix(undefined, "fooooooooo", false, 0, 0);
}

test "TestCompletionListInUnclosedElementAccessExpression02" {
    const content =
        \\var x;
        \\var y = (p) => x[/*1*/
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
//                 "p",
//                 "x",
//             },
//         },
//     });
}

test "TestGetOccurrencesPrivate2" {
    const content =
        \\namespace m {
        \\    export class C1 {
        \\        public pub1;
        \\        public pub2;
        \\        private priv1;
        \\        private priv2;
        \\        protected prot1;
        \\        protected prot2;
        \\
        \\        public public;
        \\        private private;
        \\        protected protected;
        \\
        \\        public constructor(public a, private b, protected c, public d, private e, protected f) {
        \\            this.public = 10;
        \\            this.private = 10;
        \\            this.protected = 10;
        \\        }
        \\
        \\        public get x() { return 10; }
        \\        public set x(value) { }
        \\
        \\        public static statPub;
        \\        private static statPriv;
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
        \\            [|private|] priv1;
        \\            protected prot1;
        \\
        \\            protected constructor(public public, protected protected, [|private|] private) {
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
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestQuickinfoVerbosityImport" {
    const content =
        \\// @module: esnext
        \\// @filename: /0.ts
        \\export type Apple = {
        \\    a: number;
        \\    b: string;
        \\}
        \\export const a: Apple = { a: 1, b: "2"};
        \\export enum Color {
        \\    Red,
        \\    Green,
        \\    Blue,
        \\}
        \\// @filename: /1.ts
        \\import * as zero from "./0";
        \\const b/*b*/ = zero;
        \\// @filename: /2.ts
        \\import { a/*a*/ } from "./0";
        \\import { Color/*c*/ } from "./0";
        \\// @filename: /3.ts
        \\export default class {
        \\    a: boolean;
        \\}
        \\// @filename: /4.ts
        \\import Foo/*d*/ from "./3";
        \\const f/*e*/ = new Foo/*f*/();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"b" = .{0, 1, 2}, .@"a" = .{0, 1}, .@"c" = .{0, 1}, .@"d" = .{0}, .@"e" = .{0, 1}, .@"f" = .{0, 1}});
}

test "TestQuickInfoUniqueSymbolJsDoc" {
    const content =
        \\// @checkJs: true
        \\// @allowJs: true
        \\// @filename: ./a.js
        \\/** @type {unique symbol} */
        \\const foo = Symbol();
        \\foo/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestCodeFixAddMissingConstToCommaSeparatedInitializer4" {
    const content =
        \\let y: any;
        \\x = 0, y = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCodeFixNotAvailable(undefined);
}

test "TestRenameCrossJsTs01" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\[|exports.[|{| "contextRangeIndex": 0 |}area|] = function (r) { return r * r; }|]
        \\// @Filename: b.ts
        \\[|import { [|{| "contextRangeIndex": 2 |}area|] } from './a';|]
        \\var t = [|area|](10);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRename(undefined, null , f.Ranges()[1], f.Ranges()[3], f.Ranges()[4]);
}

test "TestSyntacticClassificationsDocComment3" {
    const content =
        \\/** @param foo { number /* } */
        \\var v;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "variable.declaration", .Text = "v"},
//     });
}

test "TestFindAllRefsForVariableInExtendsClause02" {
    const content =
        \\/*1*/interface /*2*/Base { }
        \\namespace n {
        \\    var Base = class { };
        \\    interface I extends /*3*/Base { }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestCodeFixTopLevelForAwait_module_noTsConfig" {
    const content =
        \\// @filename: /dir/a.ts
        \\declare const p: number[];
        \\for await (const _ of p);
        \\export {};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCodeFixNotAvailable(undefined, "fixModuleOption");
}

test "TestSignatureHelpConstructorOverload" {
    const content =
        \\class clsOverload { constructor(); constructor(test: string); constructor(test?: string) { } }
        \\var x = new clsOverload(/*1*/);
        \\var y = new clsOverload(/*2*/'');
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // f.VerifySignatureHelp(undefined, .{.Text = "clsOverload(): clsOverload", .ParameterCount = 0, .OverloadsCount = 2});
    _ = f.GoToMarker(undefined, "2");
    // f.VerifySignatureHelp(undefined, .{.Text = "clsOverload(test: string): clsOverload", .ParameterCount = 1, .ParameterName = "test", .ParameterSpan = "test: string", .OverloadsCount = 2});
}

test "TestGetOccurrencesDeclare2" {
    const content =
        \\namespace m {
        \\    export class C1 {
        \\        public pub1;
        \\        public pub2;
        \\        private priv1;
        \\        private priv2;
        \\        protected prot1;
        \\        protected prot2;
        \\
        \\        public public;
        \\        private private;
        \\        protected protected;
        \\
        \\        public constructor(public a, private b, protected c, public d, private e, protected f) {
        \\            this.public = 10;
        \\            this.private = 10;
        \\            this.protected = 10;
        \\        }
        \\
        \\        public get x() { return 10; }
        \\        public set x(value) { }
        \\
        \\        public static statPub;
        \\        private static statPriv;
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
        \\        [|declare|] var foo;
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
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestFormatNoSpaceBeforeCloseBrace1" {
    const content =
        \\new Foo(1, /* comment */    );
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.VerifyCurrentFileContent(undefined, "new Foo(1, /* comment */);");
}

test "TestBasicClassMembers" {
    const content =
        \\class n {
        \\    constructor (public x: number, public y: number, private z: string) { }
        \\}
        \\var t = new n(0, 1, '');
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToEOF(undefined);
    _ = f.Insert(undefined, "t.");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "x",
//                 "y",
//             },
//             .Excludes = &.{
//                 "z",
//             },
//         },
//     });
}

test "TestImportNameCodeFix_symlink_own_package_2" {
    const content =
        \\// @Filename: /packages/a/test.ts
        \\// @Symlink: /node_modules/a/test.ts
        \\x;
        \\// @Filename: /packages/a/utils.ts
        \\// @Symlink: /node_modules/a/utils.ts
        \\import {} from "a/utils";
        \\export const x = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/packages/a/test.ts");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { x } from \"./utils\";\n\nx;",
    }, null );
}

test "TestGoToSource8_mapFromAtTypes" {
    const content =
        \\// @lib: es5
        \\// @moduleResolution: bundler
        \\// @Filename: /home/src/workspaces/project/node_modules/lodash/package.json
        \\{ "name": "lodash", "version": "4.17.15", "main": "./lodash.js" }
        \\// @Filename: /home/src/workspaces/project/node_modules/lodash/lodash.js
        \\;(function() {
        \\    /**
        \\     * Adds two numbers.
        \\     *
        \\     * @static
        \\     * @memberOf _
        \\     * @since 3.4.0
        \\     * @category Math
        \\     * @param {number} augend The first number in an addition.
        \\     * @param {number} addend The second number in an addition.
        \\     * @returns {number} Returns the total.
        \\     * @example
        \\     *
        \\     * _.add(6, 4);
        \\     * // => 10
        \\     */
        \\    var [|/*variable*/add|] = createMathOperation(function(augend, addend) {
        \\     return augend + addend;
        \\    }, 0);
        \\
        \\    function lodash(value) {}
        \\    lodash.[|/*property*/add|] = add;
        \\
        \\    /** Detect free variable 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.VerifyBaselineGoToSourceDefinition(undefined, "start");
}

test "TestTsxFindAllReferences3" {
    const content =
        \\//@Filename: file.tsx
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\    }
        \\    interface ElementAttributesProperty { props }
        \\}
        \\class MyClass {
        \\  props: {
        \\    /*1*/name?: string;
        \\    size?: number;
        \\}
        \\
        \\
        \\var x = <MyClass name='hello'/>;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestFindAllRefsUnresolvedSymbols3" {
    const content =
        \\import * as /*a0*/Bar from "does-not-exist";
        \\
        \\let a: /*a1*/Bar;
        \\let b: /*a2*/Bar<string>;
        \\let c: /*a3*/Bar<string, number>;
        \\let d: /*a4*/Bar./*b0*/X;
        \\let e: /*a5*/Bar./*b1*/X<string>;
        \\let f: /*a6*/Bar./*c0*/X./*d0*/Y;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "a0", "a1", "a2", "a3", "a4", "a5", "a6", "b0", "b1", "c0", "d0");
}

test "TestGoToDefinitionYield3" {
    const content =
        \\class C {
        \\    notAGenerator() {
        \\      [|/*start1*/yield|] 0;
        \\    }
        \\
        \\    foo*/*end2*/() {
        \\      [|/*start2*/yield|] 0;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "start1", "start2");
}

test "TestCompletionListInvalidMemberNames_startWithSpace" {
    const content =
        \\declare const x: { " foo": 0, "foo ": 1 };
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
//                     .Label =      "foo ",
//                     .InsertText = undefined("[\"foo \"]"),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "foo ",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestGoToDefinitionAcrossMultipleProjects" {
    const content =
        \\//@Filename: a.ts
        \\var /*def1*/x: number;
        \\//@Filename: b.ts
        \\var /*def2*/x: number;
        \\//@Filename: c.ts
        \\var /*def3*/x: number;
        \\//@Filename: d.ts
        \\var /*def4*/x: number;
        \\//@Filename: e.ts
        \\/// <reference path="a.ts" />
        \\/// <reference path="b.ts" />
        \\/// <reference path="c.ts" />
        \\/// <reference path="d.ts" />
        \\[|/*use*/x|]++;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "use");
}

test "TestGetOccurrencesLoopBreakContinue3" {
    const content =
        \\var arr = [1, 2, 3, 4];
        \\label1: for (var n in arr) {
        \\    break;
        \\    continue;
        \\    break label1;
        \\    continue label1;
        \\
        \\    label2: for (var i = 0; i < arr[n]; i++) {
        \\        break label1;
        \\        continue label1;
        \\
        \\        break;
        \\        continue;
        \\        break label2;
        \\        continue label2;
        \\
        \\        function foo() {
        \\            label3: [|w/**/hile|] (true) {
        \\                [|break|];
        \\                [|continue|];
        \\                [|break|] label3;
        \\                [|continue|] label3;
        \\
        \\                // these cross function boundaries
        \\                break label1;
        \\                continue label1;
        \\                break label2;
        \\                continue label2;
        \\
        \\                label4: do {
        \\                    break;
        \\                    continue;
        \\                    break label4;
        \\                    continue label4;
        \\
        \\                    [|break|] label3;
        \\                    [|continue|] label3;
        \\
        \\                    switch (10) {
        \\                        case 1:
        \\                        case 2:
        \\                            break;
        \\                            break label4;
        \\                        default:
        \\                            continue;
        \\                    }
        \\
        \\                    // these cross function boundaries
        \\                    break label1;
        \\                    continue label1;
        \\                    break label2;
        \\                    continue label2;
        \\                    () => { break; }
        \\                } while (true)
        \\            }
        \\        }
        \\    }
        \\}
        \\
        \\label5: while (true) break label5;
        \\
        \\label7: while (true) continue label5;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestCompletionsInRequire" {
    const content =
        \\// @allowJs: true
        \\// @Filename: foo.js
        \\var foo = require("/**/"
        \\
        \\foo();
        \\
        \\/**
        \\ * @return {void}
        \\ */
        \\function foo() {
        \\}
        \\// @Filename: package.json
        \\ { "dependencies": { "fake-module": "latest" } }
        \\// @Filename: node_modules/fake-module/index.js
        \\/* fake-module */
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
//                 "fake-module",
//             },
//         },
//     });
}

test "TestGenericCloduleCompletionList" {
    const content =
        \\class D<T> { x: number }
        \\namespace D { export function f() { } }
        \\var d: D<number>;
        \\d./**/
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
//                 "x",
//             },
//         },
//     });
}

test "TestCompletionForStringLiteral_quotePreference" {
    const content =
        \\enum A {
        \\    A,
        \\    B,
        \\    C
        \\}
        \\interface B {
        \\    a: keyof typeof A;
        \\}
        \\const b: B = {
        \\    a: /**/
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
//             .Includes = &.{
//                 &.{
//                     .Label = "'A'",
//                 },
//                 &.{
//                     .Label = "'B'",
//                 },
//                 &.{
//                     .Label = "'C'",
//                 },
//             },
//         },
//         .UserPreferences = &.{.QuotePreference = lsutil.QuotePreference("single")},
//     });
}

test "TestCompletionsBigIntShowNoCompletions" {
    const content =
        \\declare const SSL_OP_SSLEAY_080_CLIENT_DH_BUG: number
        \\const foo = 0n/*1*/;
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
//             .Exact = &.{},
//         },
//     });
}

test "TestDoubleUnderscoreCompletions" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\function MyObject(){
        \\    this.__property = 1;
        \\}
        \\var instance = new MyObject();
        \\instance./*1*/
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
//                     .Label =  "__property",
//                     .Detail = undefined("(property) MyObject.__property: number"),
//                 },
//                 &.{
//                     .Label =    "instance",
//                     .SortText = undefined(string(ls.SortTextJavascriptIdentifiers)),
//                 },
//                 &.{
//                     .Label =    "MyObject",
//                     .SortText = undefined(string(ls.SortTextJavascriptIdentifiers)),
//                 },
//             },
//         },
//     });
}

test "TestFindAllRefsForDefaultExport03" {
    const content =
        \\/*1*/function /*2*/f() {
        \\    return 100;
        \\}
        \\
        \\/*3*/export default /*4*/f;
        \\
        \\var x: typeof /*5*/f;
        \\
        \\var y = /*6*/f();
        \\
        \\/*7*/namespace /*8*/f {
        \\    var local = 100;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5", "6", "7", "8");
}

test "TestAutoImportPaths" {
    const content =
        \\// @Filename: /package1/jsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    checkJs: true,
        \\    "paths": {
        \\      "package1/*": ["./*"],
        \\      "package2/*": ["../package2/*"]
        \\    },
        \\    "baseUrl": "."
        \\  },
        \\  "include": [
        \\    ".",
        \\    "../package2"
        \\  ]
        \\}
        \\// @Filename: /package1/file1.js
        \\bar/**/
        \\// @Filename: /package2/file1.js
        \\export const bar = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"package2/file1"}, &.{.ImportModuleSpecifierPreference = "shortest"});
}

test "TestCodeFixClassImplementClassFunctionVoidInferred" {
    const content =
        \\class A {
        \\    f() {}
        \\}
        \\
        \\class B implements A {[| |]}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'A'",
        .NewFileContent = "class A {\n    f() {}\n}\n\nclass B implements A {\n    f(): void {\n        throw new Error(\"Method not implemented.\");\n    }\n}",
        .Index = 0,
    });
}

test "TestGetOccurrencesThrow6" {
    const content =
        \\[|throw|] 100;
        \\
        \\try {
        \\    throw 0;
        \\    var x = () => { throw 0; };
        \\}
        \\catch (y) {
        \\    var x = () => { throw 0; };
        \\    [|throw|] 200;
        \\}
        \\finally {
        \\    [|throw|] 300;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestCompletionAtCaseClause" {
    const content =
        \\// @lib: es5
        \\case /**/
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
//             .Exact = CompletionGlobals,
//         },
//     });
}

test "TestQuickInfoStaticPrototypePropertyOnClass" {
    const content =
        \\class c1 {
        \\}
        \\class c2<T> {
        \\}
        \\class c3 {
        \\    constructor() {
        \\    }
        \\}
        \\class c4 {
        \\    constructor(param: string);
        \\    constructor(param: number);
        \\    constructor(param: any) {
        \\    }
        \\}
        \\c1./*1*/prototype;
        \\c2./*2*/prototype;
        \\c3./*3*/prototype;
        \\c4./*4*/prototype;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "(property) c1.prototype: c1", "");
    // f.VerifyQuickInfoAt(undefined, "2", "(property) c2<T>.prototype: c2<any>", "");
    // f.VerifyQuickInfoAt(undefined, "3", "(property) c3.prototype: c3", "");
    // f.VerifyQuickInfoAt(undefined, "4", "(property) c4.prototype: c4", "");
}

test "TestNavigationBarItemsEmptyConstructors" {
    const content =
        \\class Test {
        \\    constructor() {
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestCompletionListInUnclosedFunction04" {
    const content =
        \\function foo(x: string, y: number, z: boolean) {
        \\    function bar(a: number, b: string, c: typeof x = /*1*/
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
//                 "b",
//             },
//         },
//     });
}

test "TestGenericFunctionWithGenericParams1" {
    const content =
        \\var obj = function f<T>(a: T) {
        \\    var x/**/x: T;
        \\    return a;
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "(local var) xx: T", "");
}

test "TestOrganizeImportsType10" {
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
    // f.VerifyOrganizeImports(undefined,
//         "import {\n    type Type1,\n    type Type2,\n    type Type3,\n    type Type4,\n    type Type5,\n    type Type6,\n    type Type7,\n    type Type8,\n    type Type9,\n    func1,\n    func2,\n    func3,\n    func4,\n    func5,\n    func6,\n    func7,\n    func8,\n    func9,\n} from \"foo\";\ninterface Use extends Type1, Type2, Type3, Type4, Type5, Type6, Type7, Type8, Type9 {}\nconsole.log(func1, func2, func3, func4, func5, func6, func7, func8, func9);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSTrue,
//         },
//     );
}

test "TestCompletionsWithGenericStringLiteral" {
    const content =
        \\// @strict: true
        \\declare function get<T, K extends keyof T>(obj: T, key: K): T[K];
        \\get({ hello: 123, world: 456 }, "/**/");
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
//                 "hello",
//                 "world",
//             },
//         },
//     });
}

test "TestCompletionsDotInArrayLiteralInObjectLiteral" {
    const content =
        \\const o = { x: [[|.|][||]/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyNonSuggestionDiagnostics(undefined, []*.{
//         .{
//             .Code =    &.{.Integer = undefined(int32(1109))},
//             .Message = .{.String = undefined("Expression expected.")},
//             .Range =   f.Ranges()[0].LSRange,
//         },
//         .{
//             .Code =    &.{.Integer = undefined(int32(1003))},
//             .Message = .{.String = undefined("Identifier expected.")},
//             .Range =   f.Ranges()[1].LSRange,
//         },
//     });
    _ = f.VerifyCompletions(undefined, "", null);
}

test "TestCompletionCloneQuestionToken" {
    const content =
        \\// @strict: false
        \\// @Filename: /file2.ts
        \\type TCallback<T = any> = (options: T) => any;
        \\type InKeyOf<E> = { [K in keyof E]?: TCallback<E[K]>; };
        \\export class Bar<A> {
        \\    baz(a: InKeyOf<A>): void { }
        \\}
        \\// @Filename: /file1.ts
        \\import { Bar } from './file2';
        \\type TwoKeys = Record<'a' | 'b', { thisFails?: any; }>
        \\class Foo extends Bar<TwoKeys> {
        \\    /**/
        \\}
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
//             .Includes = &.{
//                 &.{
//                     .Label =      "baz",
//                     .InsertText = undefined("baz(a: { a?: (options: { thisFails?: any; }) => any; b?: (options: { thisFails?: any; }) => any; }): void {\n}"),
//                     .FilterText = undefined("baz"),
//                 },
//             },
//         },
//     });
}

test "TestCompletionsImport_ofAlias_preferShortPath" {
    const content =
        \\// @module: commonJs
        \\// @noLib: true
        \\// @Filename: /foo/index.ts
        \\export { foo } from "./lib/foo";
        \\// @Filename: /foo/lib/foo.ts
        \\export const foo = 0;
        \\// @Filename: /user.ts
        \\fo/**/
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
//                         .Label = "foo",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "./foo",
//                             },
//                         },
//                         .Detail =              undefined("(alias) const foo: 0\nexport foo"),
//                         .Kind =                undefined(lsproto.CompletionItemKindVariable),
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     },
//                 }, true,
//             ),
//         },
//     });
    // f.VerifyApplyCodeActionFromCompletion(undefined, undefined(""), &.{
//         .Name =        "foo",
//         .Source =      "./foo",
//         .Description = "Add import from \"./foo\"",
//         .NewFileContent = undefined("import { foo } from \"./foo\";\n\nfo"),
//     });
}

test "TestFormatNoSpaceAfterTemplateHeadAndMiddle" {
    const content =
        \\const a1 = 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.GetOptions();
    // f.Configure(undefined, opts429);
    _ = f.FormatDocument(undefined, "");
    _ = f.VerifyCurrentFileContent(undefined, "const a1 = `${1}${1}`;\n" ++ "const a2 = `\n" ++ "    ${1}${1}\n" ++ "`;\n" ++ "const a3 = `\n" ++ "\n" ++ "\n" ++ "    ${1}${1}\n" ++ "`;\n" ++ "const a4 = `\n" ++ "\n" ++ "    ${1}${1}\n" ++ "\n" ++ "`;\n" ++ "const a5 = `text ${1} text ${1} text`;\n" ++ "const a6 = `\n" ++ "    text ${1}\n" ++ "    text ${1}\n" ++ "    text\n" ++ "`;");
}

test "TestExternalModuleIntellisense" {
    const content =
        \\// @module: commonjs
        \\// @Filename: externalModuleIntellisense_file0.ts
        \\export = express;
        \\function express(): express.ExpressServer;
        \\namespace express {
        \\    export interface ExpressServer {
        \\        enable(name: string): ExpressServer;
        \\        post(path: RegExp, handler: (req: Function) => void): void;
        \\    }
        \\    export class ExpressServerRequest {
        \\    }
        \\}
        \\// @Filename: externalModuleIntellisense_file1.ts
        \\///<reference path='externalModuleIntellisense_file0.ts'/>
        \\import express = require('./externalModuleIntellisense_file0');
        \\var x = express();/*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 0);
    _ = f.GoToEOF(undefined);
    _ = f.Insert(undefined, "x.");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "enable",
//                 "post",
//             },
//         },
//     });
}

test "TestImportNameCodeFix_importType6" {
    const content =
        \\// @module: es2015
        \\// @esModuleInterop: true
        \\// @jsx: react
        \\// @Filename: /types.d.ts
        \\declare module "react" { var React: any; export = React; export as namespace React; }
        \\// @Filename: /a.tsx
        \\import type React from "react";
        \\function Component() {}
        \\(<Component/**/ />)
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import React from \"react\";\nfunction Component() {}\n(<Component />)",
    }, null );
}

test "TestFormattingOfChainedLambda" {
    const content =
        \\var fn = (x: string) => ()=> alert(x)/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, ";");
    _ = f.VerifyCurrentLineContent(undefined, "var fn = (x: string) => () => alert(x);");
}

test "TestJsDocIndentationPreservation2" {
    const content =
        \\// @allowJs: true
        \\// @Filename: Foo.js
        \\/**
        \\    Does some stuff.
        \\        Second line.
        \\        Third line.
        \\*/
        \\function foo/**/(){}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyQuickInfoIs(undefined, "function foo(): void", "Does some stuff.\n    Second line.\n\tThird line.");
}

test "TestReferencesInStringLiteralValueWithMultipleProjects" {
    const content =
        \\// @Filename: /home/src/workspaces/project/a/tsconfig.json
        \\{ "files": ["a.ts"], "compilerOptions": { "lib": ["es5"] } }
        \\// @Filename: /home/src/workspaces/project/a/a.ts
        \\/// <reference path="../b/b.ts" />
        \\const str: string = "hello/*1*/";
        \\// @Filename: /home/src/workspaces/project/b/tsconfig.json
        \\{ "files": ["b.ts"], "compilerOptions": { "lib": ["es5"] } }
        \\// @Filename: /home/src/workspaces/project/b/b.ts
        \\const str2: string = "hello/*2*/";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestClassInterfaceInsert" {
    const content =
        \\interface Intersection {
        \\    dist: number;
        \\}
        \\/*interfaceGoesHere*/
        \\class /*className*/Sphere {
        \\    constructor(private center) {
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "className", "class Sphere", "");
    _ = f.GoToMarker(undefined, "interfaceGoesHere");
    _ = f.Insert(undefined, "\ninterface Surface {\n    reflect: () => number;\n}\n");
    // f.VerifyQuickInfoAt(undefined, "className", "class Sphere", "");
}

test "TestCompletionsExternalModuleRenamedExports" {
    const content =
        \\// @Filename: other.ts
        \\export {};
        \\// @Filename: index.ts
        \\const c = 0;
        \\export { c as yeahThisIsTotallyInScopeHuh };
        \\export * as alsoNotInScope from "./other";
        \\
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
//                 "c",
//             },
//             .Excludes = &.{
//                 "yeahThisIsTotallyInScopeHuh",
//                 "alsoNotInScope",
//             },
//         },
//     });
}

test "TestTsxCompletionInFunctionExpressionOfChildrenCallback" {
    const content =
        \\//@module: commonjs
        \\//@jsx: preserve
        \\// @Filename: 1.tsx
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\    }
        \\    interface ElementAttributesProperty { props; }
        \\}
        \\interface IUser {
        \\    Name: string;
        \\}
        \\interface IFetchUserProps {
        \\    children: (user: IUser) => any;
        \\}
        \\function FetchUser(props: IFetchUserProps) { return undefined; }
        \\function UserName() {
        \\    return (
        \\        <FetchUser>
        \\            { user => (
        \\                <h1>{ user./**/ }</h1>
        \\            )}
        \\        </FetchUser>
        \\    );
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, "", null);
}

test "TestImportNameCodeFixInferEndingPreference_classic" {
    const content =
        \\// @module: esnext
        \\// @checkJs: true
        \\// @allowJs: true
        \\// @noEmit: true
        \\// @Filename: /a.js
        \\export const a = 0;
        \\// @Filename: /b.js
        \\export const b = 0;
        \\// @Filename: /c.js
        \\import { a } from "./a.js";
        \\
        \\b/**/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"./b.js"}, null );
}

test "TestCompletionsImport_umdModules1_globalAccess" {
    const content =
        \\// @filename: /package.json
        \\{ "dependencies": { "@types/classnames": "*" } }
        \\// @filename: /tsconfig.json
        \\{ "compilerOptions": { "allowUmdGlobalAccess": true, "types": ["*"] } }
        \\// @filename: /node_modules/@types/classnames/package.json
        \\{ "name": "@types/classnames", "types": "index.d.ts" }
        \\// @filename: /node_modules/@types/classnames/index.d.ts
        \\declare const classNames: () => string;
        \\export = classNames;
        \\export as namespace classNames;
        \\// @filename: /SomeReactComponent.tsx
        \\import * as React from 'react';
        \\
        \\const el1 = <div className={class/*1*/}>foo</div>;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =               "classNames",
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestGoToDefinitionBuiltInValues" {
    const content =
        \\var u = /*undefined*/undefined;
        \\var n = /*null*/null;
        \\var a = function() { return /*arguments*/arguments; };
        \\var t = /*true*/true;
        \\var f = /*false*/false;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, f.MarkerNames());
}

test "TestFindAllRefs_importType_js2" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: /a.js
        \\module.exports = class C {};
        \\module.exports./**/D = class D {};
        \\// @Filename: /b.js
        \\/** @type {import("./a")} */
        \\const x = 0;
        \\/** @type {import("./a").D} */
        \\const y = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
    // f.VerifyBaselineFindAllReferences(undefined, "");
}

