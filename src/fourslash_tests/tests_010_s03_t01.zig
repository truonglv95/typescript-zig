const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestImportNameCodeFixNewImportRootDirs1" {
    const content =
        \\// @Filename: a/f1.ts
        \\[|foo/*0*/();|]
        \\// @Filename: a/b/index.ts
        \\export function foo() {};
        \\// @Filename: tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "rootDirs": [
        \\            "a"
        \\        ]
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { foo } from \"./b\";\n\nfoo();",
    }, null );
}

test "TestOrganizeImports16" {
    const content =
        \\import { a, A, b } from "foo";
        \\interface Use extends A {}
        \\console.log(a, b);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOrganizeImports(undefined,
//         "import { a, A, b } from \"foo\";\ninterface Use extends A {}\nconsole.log(a, b);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
    _ = f.ReplaceLine(undefined, 0, "import { a, A, b } from \"foo1\";");
    // f.VerifyOrganizeImports(undefined,
//         "import { a, A, b } from \"foo1\";\ninterface Use extends A {}\nconsole.log(a, b);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSUnknown,
//         },
//     );
    _ = f.ReplaceLine(undefined, 0, "import { a, A, b } from \"foo2\";");
    // f.VerifyOrganizeImports(undefined,
//         "import { a, A, b } from \"foo2\";\ninterface Use extends A {}\nconsole.log(a, b);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSTrue,
//         },
//     );
    _ = f.ReplaceLine(undefined, 0, "import { a, A, b } from \"foo3\";");
    // f.VerifyOrganizeImports(undefined,
//         "import { A, a, b } from \"foo3\";\ninterface Use extends A {}\nconsole.log(a, b);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSFalse,
//         },
//     );
}

test "TestImportTypesDeclarationDiagnosticsNoServerError" {
    const content =
        \\// @declaration: true
        \\// @Filename: node_modules/foo/index.d.ts
        \\export function f(): I;
        \\export interface I {
        \\  x: number;
        \\}
        \\// @Filename: a.ts
        \\import { f } from "foo";
        \\export const x = f();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFileNumber(undefined, 1);
    _ = f.VerifyNonSuggestionDiagnostics(undefined, null);
}

test "TestSignatureHelpOnSuperWhenMembersAreNotResolved" {
    const content =
        \\class A { }
        \\class B extends A { constructor(public x: string) { } }
        \\class C extends B {
        \\    constructor() {
        \\        /*1*/
        \\     }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, "super(");
    // f.VerifySignatureHelp(undefined, .{.Text = "B(x: string): B"});
}

test "TestGetOutliningForBlockComments" {
    const content =
        \\[|/*
        \\    Block comment at the beginning of the file before module:
        \\        line one of the comment
        \\        line two of the comment
        \\        line three
        \\        line four
        \\        line five
        \\*/|]
        \\module Sayings[| {
        \\    [|/*
        \\    Comment before class:
        \\        line one of the comment
        \\        line two of the comment
        \\        line three
        \\        line four
        \\        line five
        \\    */|]
        \\    export class Greeter[| {
        \\        [|/*
        \\            Comment before a string identifier
        \\            line two of the comment
        \\        */|]
        \\        greeting: string;
        \\        [|/*
        \\            constructor
        \\            parameter message as a string
        \\        */|]
        \\        
        \\        [|/*
        \\            Multiple comments should be collapsed individually
        \\        */|]
        \\        constructor(message: string /* do not collapse this */)[| {
        \\            this.greeting = message;
        \\        }|]
        \\        [|/*
        \\            method of a class
        \\        */|]
        \\        greet()[| {
        \\            return "Hello, " + this.greeting;
        \\        }|]
        \\    }|]
        \\}|]
        \\
        \\[|/*
        \\    Block comment for interface. The ending can be on the same line as the declaration.
        \\*/|]interface IFoo[| {
        \\    [|/*
        \\    Multiple block comments
        \\    */|]
        \\
        \\    [|/*  
        \\    should be collapsed
        \\    */|]
        \\
        \\    [|/*
        \\    individually
        \\    */|]
        \\
        \\                                                                                                                              [|/*
        \\                                                                    this comment has trailing space before /* and after *-/ signs
        \\    */|]                                                                          
        \\
        \\    [|/**
        \\     *
        \\     *
        \\     *
        \\     */|]
        \\
        \\    [|/*
        \\    */|]
        \\
        \\    [|/*
        \\    */|]
        \\    // single line comments in the middle should not have an effect
        \\    [|/*
        \\    */|]
        \\
        \\    [|/*
        \\    */|]
        \\
        \\    [|/*
        \\    this block comment ends     
        \\    on the same line */|]  [|/* where the following comment starts
        \\        should be collapsed separately
        \\    */|]
        \\
        \\    getDist(): number;
        \\}|]
        \\
        \\var x =[|{
        \\  a:1,
        \\  b: 2,
        \\  [|/*
        \\        Over a function in an object literal
        \\  */|]
        \\  get foo()[| {
        \\    return 1;
        \\  }|]
        \\}|]
        \\
        \\// Over a function expression assigned to a variable
        \\ [|/**
        \\  * Return a sum
        \\  * @param {Number} y
        \\  * @param {Number} z
        \\  * @returns {Number} the sum of y and z
        \\  */|]
        \\ const sum2 = (y, z) =>[| {
        \\     return y + z;
        \\ }|];
        \\
        \\// Over a variable
        \\[|/**
        \\ * foo
        \\ */|]
        \\const foo = null;
        \\
        \\function Foo()[| {
        \\   [|/**
        \\     * Description
        \\     *
        \\     * @param {string} param
        \\     * @returns
        \\     */|]
        \\    this.method = function (param)[| {
        \\    }|]
        \\
        \\   [|/**
        \\     * Description
        \\     *
        \\     * @param {string} param
        \\     * @returns
        \\     */|]
        \\    function method(param)[| {
        \\    }|]
        \\}|]
        \\
        \\function fn1()[| {
        \\    [|/**
        \\     * comment
        \\     */|]
        \\}|]
        \\function fn2()[| {
        \\    [|/**
        \\     * comment
        \\     */|]
        \\
        \\    [|/**
        \\     * comment
        \\     */|]
        \\}|]
        \\function fn3()[| {
        \\    const x = 1;
        \\
        \\    [|/**
        \\     * comment
        \\     */|]
        \\
        \\    [|/**
        \\     * comment
        \\     */|]
        \\}|]
        \\function fn4()[| {
        \\    [|/**
        \\     * comment
        \\     */|]
        \\     const x = 1;
        \\
        \\    [|/**
        \\     * comment
        \\     */|]
        \\}|]
        \\function fn5()[| {
        \\    [|/**
        \\     * comment
        \\     */|]
        \\
        \\    [|/**
        \\     * comment
        \\     */|]
        \\     return 1;
        \\}|]
        \\function fn6()[| {
        \\    [|/**
        \\     * comment
        \\     */|]
        \\
        \\    [|/**
        \\     * comment
        \\     */|]
        \\    const x = 1;
        \\}|]
        \\
        \\[|/*
        \\comment
        \\*/|]
        \\
        \\f6();
        \\
        \\class C1[| {
        \\    [|/**
        \\     * comment
        \\     */|]
        \\
        \\    [|/**
        \\     * comment
        \\     */|]
        \\}|]
        \\class C2[| {
        \\    private prop = 1;
        \\    [|/**
        \\     * comment
        \\     */|]
        \\
        \\    [|/**
        \\     * comment
        \\     */|]
        \\}|]
        \\class C3[| {
        \\    [|/**
        \\     * comment
        \\     */|]
        \\
        \\    private prop = 1;
        \\    [|/**
        \\     * comment
        \\     */|]
        \\}|]
        \\class C4[| {
        \\    [|/**
        \\     * comment
        \\     */|]
        \\
        \\    [|/**
        \\     * comment
        \\     */|]
        \\    private prop = 1;
        \\}|]
        \\
        \\[|/*
        \\comment
        \\*/|]
        \\new C4();
        \\
        \\module M1[| {
        \\    [|/**
        \\     * comment
        \\     */|]
        \\
        \\    [|/**
        \\     * comment
        \\     */|]
        \\}|]
        \\module M2[| {
        \\    export const a = 1;
        \\    [|/**
        \\     * comment
        \\     */|]
        \\
        \\    [|/**
        \\     * comment
        \\     */|]
        \\}|]
        \\module M3[| {
        \\    [|/**
        \\     * comment
        \\     */|]
        \\    export const a = 1;
        \\
        \\    [|/**
        \\     * comment
        \\     */|]
        \\}|]
        \\module M4[| {
        \\    [|/**
        \\     * comment
        \\     */|]
        \\
        \\    [|/**
        \\     * comment
        \\     */|]
        \\    export const a = 1;
        \\}|]
        \\interface I1[| {
        \\    [|/**
        \\     * comment
        \\     */|]
        \\
        \\    [|/**
        \\     * comment
        \\     */|]
        \\}|]
        \\interface I2[| {
        \\    x: number;
        \\    [|/**
        \\     * comment
        \\     */|]
        \\
        \\    [|/**
        \\     * comment
        \\     */|]
        \\}|]
        \\interface I3[| {
        \\    [|/**
        \\     * comment
        \\     */|]
        \\    x: number;
        \\
        \\    [|/**
        \\     * comment
        \\     */|]
        \\}|]
        \\interface I4[| {
        \\    [|/**
        \\     * comment
        \\     */|]
        \\
        \\    [|/**
        \\     * comment
        \\     */|]
        \\    x: number;
        \\}|]
        \\[|{
        \\    [|/**
        \\     * comment
        \\     */|]
        \\
        \\    [|/**
        \\     * comment
        \\     */|]
        \\}|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOutliningSpans(undefined);
}

test "TestCompletionListOutsideOfClosedArrowFunction02" {
    const content =
        \\// no a or b
        \\(a, b) => { }/*1*/
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
//             .Excludes = &.{
//                 "a",
//                 "b",
//             },
//         },
//     });
}

test "TestGetJavaScriptQuickInfo8" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: file.js
        \\let x = {
        \\    /** @type {number} */
        \\    get m() {
        \\        return undefined;
        \\    }
        \\}
        \\x.m/*1*/;
        \\
        \\class Foo {
        \\    /** @type {string} */
        \\    get b() {
        \\        return undefined;
        \\    }
        \\}
        \\var y = new Foo();
        \\y.b/*2*/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, ".");
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
    _ = f.Backspace(undefined, 1);
    _ = f.GoToMarker(undefined, "2");
    _ = f.Insert(undefined, ".");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label = "substring",
//                     .Kind =  undefined(lsproto.CompletionItemKindMethod),
//                 },
//             },
//         },
//     });
}

test "TestQuickInfoOfStringPropertyNames1" {
    const content =
        \\interface foo {
        \\    "foo bar": string;
        \\}
        \\var f: foo;
        \\var /*1*/r = f['foo bar'];
        \\class bar {
        \\    'hello world': number;
        \\    '1': string;
        \\    constructor() {
        \\        bar['hello world'] = 3;
        \\    }
        \\}
        \\var b: bar;
        \\var /*2*/r2 = b["hello world"];
        \\var /*3*/r4 = b['1'];
        \\var /*4*/r5 = b[1];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "var r: string", "");
    // f.VerifyQuickInfoAt(undefined, "2", "var r2: number", "");
    // f.VerifyQuickInfoAt(undefined, "3", "var r4: string", "");
    // f.VerifyQuickInfoAt(undefined, "4", "var r5: string", "");
}

test "TestCodeFixClassImplementInterfaceMappedType1" {
    const content =
        \\interface I<X> {
        \\    x: { readonly [K in keyof X]: X[K] };
        \\}
        \\class C<Y> implements I<Y> {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'I<Y>'",
        .NewFileContent = "interface I<X> {\n    x: { readonly [K in keyof X]: X[K] };\n}\nclass C<Y> implements I<Y> {\n    x: { readonly [K in keyof Y]: Y[K]; };\n}",
        .Index = 0,
    });
}

test "TestCompletionListInTypeLiteralInTypeParameter20" {
    const content =
        \\// @jsx: preserve
        \\// @filename: a.tsx
        \\const Component1 = <T extends { x: 'one' | 'two' }>() => <></>;
        \\const Component2 = <T extends 'one' | 'two'>() => <></>;
        \\
        \\<Component1<{ x: '/*0*/' }>></Component>;
        \\<Component1<{ x: '/*1*/' }>/>;
        \\<Component2<'/*2*/'>></Component>;
        \\<Component2<'/*3*/'>/>;
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
//             .Unsorted = &.{
//                 "one",
//                 "two",
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
//             .Unsorted = &.{
//                 "one",
//                 "two",
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
//             .Unsorted = &.{
//                 "one",
//                 "two",
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
//             .Unsorted = &.{
//                 "one",
//                 "two",
//             },
//         },
//     });
}

