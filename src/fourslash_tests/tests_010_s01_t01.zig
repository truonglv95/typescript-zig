const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestJsdocTypedefTagTypeExpressionCompletion" {
    const content =
        \\// @lib: es5
        \\interface I {
        \\    age: number;
        \\}
        \\ class Foo {
        \\     property1: string;
        \\     constructor(value: number) { this.property1 = "hello"; }
        \\     static method1() {}
        \\     method3(): number { return 3; }
        \\     /**
        \\      * @param {string} foo A value.
        \\      * @returns {number} Another value
        \\      * @mytag
        \\      */
        \\     method4(foo: string) { return 3; }
        \\ }
        \\ namespace Foo.Namespace { export interface SomeType { age2: number } }
        \\ /**
        \\  * @type { /*type1*/Foo./*typeFooMember*/Namespace./*NamespaceMember*/SomeType }
        \\  */
        \\var x;
        \\/*globalValue*/
        \\x./*valueMemberOfSomeType*/
        \\var x1: Foo;
        \\x1./*valueMemberOfFooInstance*/;
        \\Foo./*valueMemberOfFoo*/;
        \\ /**
        \\  * @type { {/*propertyName*/ageX: number} }
        \\  */
        \\var y;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "type1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label = "Foo",
//                     .Kind =  undefined(lsproto.CompletionItemKindClass),
//                 },
//                 &.{
//                     .Label = "I",
//                     .Kind =  undefined(lsproto.CompletionItemKindInterface),
//                 },
//             },
//             .Excludes = &.{
//                 "Namespace",
//                 "SomeType",
//                 "x",
//                 "x1",
//                 "y",
//                 "method1",
//                 "property1",
//                 "method3",
//                 "method4",
//                 "foo",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "typeFooMember", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label = "Namespace",
//                     .Kind =  undefined(lsproto.CompletionItemKindModule),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "NamespaceMember", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label = "SomeType",
//                     .Kind =  undefined(lsproto.CompletionItemKindInterface),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "globalValue", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label = "Foo",
//                     .Kind =  undefined(lsproto.CompletionItemKindClass),
//                 },
//                 &.{
//                     .Label = "x",
//                     .Kind =  undefined(lsproto.CompletionItemKindVariable),
//                 },
//                 &.{
//                     .Label = "x1",
//                     .Kind =  undefined(lsproto.CompletionItemKindVariable),
//                 },
//                 &.{
//                     .Label = "y",
//                     .Kind =  undefined(lsproto.CompletionItemKindVariable),
//                 },
//             },
//             .Excludes = &.{
//                 "I",
//                 "Namespace",
//                 "SomeType",
//                 "method1",
//                 "property1",
//                 "method3",
//                 "method4",
//                 "foo",
//             },
//         },
//     });
    _ = f.VerifyCompletions(undefined, "valueMemberOfSomeType", null);
    // f.VerifyCompletions(undefined, "valueMemberOfFooInstance", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label = "method3",
//                     .Kind =  undefined(lsproto.CompletionItemKindMethod),
//                 },
//                 &.{
//                     .Label = "method4",
//                     .Kind =  undefined(lsproto.CompletionItemKindMethod),
//                 },
//                 &.{
//                     .Label = "property1",
//                     .Kind =  undefined(lsproto.CompletionItemKindField),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "valueMemberOfFoo", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionFunctionMembersPlus(
//                 &.{
//                     &.{
//                         .Label =    "method1",
//                         .Kind =     undefined(lsproto.CompletionItemKindMethod),
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
    _ = f.VerifyCompletions(undefined, "propertyName", null);
}

test "TestAutoImportJsDocImport1" {
    const content =
        \\// @verbatimModuleSyntax: true
        \\// @target: esnext
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: /foo.ts
        \\ export const A = 1;
        \\ export type B = { x: number };
        \\ export type C = 1;
        \\ export class D { y: string }
        \\// @Filename: /test.js
        \\/**
        \\ * @import { A, D, C } from "./foo"
        \\ */
        \\
        \\/**
        \\ * @param { typeof A } a
        \\ * @param { B/**/ | C } b
        \\ * @param { C } c
        \\ * @param { D } d
        \\ */
        \\export function f(a, b, c, d) { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "/**\n * @import { A, D, C, B } from \"./foo\"\n */\n\n/**\n * @param { typeof A } a\n * @param { B | C } b\n * @param { C } c\n * @param { D } d\n */\nexport function f(a, b, c, d) { }",
    }, null );
}

test "TestCompletionListInvalidMemberNames2" {
    const content =
        \\// @lib: es5
        \\declare var Symbol: SymbolConstructor;
        \\interface SymbolConstructor {
        \\    readonly hasInstance: symbol;
        \\}
        \\interface Function {
        \\    [Symbol.hasInstance](value: any): boolean;
        \\}
        \\interface SomeInterface {
        \\    (value: number): any;
        \\}
        \\var _ : SomeInterface;
        \\_./**/
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
//             .Exact = CompletionFunctionMembersWithPrototype,
//         },
//     });
}

test "TestAddInterfaceMemberAboveClass" {
    const content =
        \\
        \\interface Intersection {
        \\    /*insertHere*/
        \\}
        \\interface Scene { }
        \\class /*className*/Sphere {
        \\    constructor() {
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "className", "class Sphere", "");
    _ = f.GoToMarker(undefined, "insertHere");
    _ = f.Insert(undefined, "ray: Ray;");
    try f.VerifyQuickInfoAt(undefined, "className", "class Sphere", "");
}

test "TestSignatureHelpForNonlocalTypeDoesNotUseImportType" {
    const content =
        \\// @Filename: exporter.ts
        \\export interface Thing {}
        \\export const Foo: () => Thing = null as any;
        \\// @Filename: usage.ts
        \\import {Foo} from "./exporter"
        \\function f(p = Foo()): void {}
        \\f(/*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // try f.VerifySignatureHelp(undefined, .{.Text = "f(p?: Thing): void"});
}

test "TestRenameJsOverloadedFunctionParameter" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: foo.js
        \\/**
        \\ * @overload
        \\ * @param {number} x
        \\ * @returns {number}
        \\ *
        \\ * @overload
        \\ * @param {string} x
        \\ * @returns {string} 
        \\ *
        \\ * @param {unknown} x
        \\ * @returns {unknown} 
        \\ */
        \\function foo(x/**/) {
        \\  return x;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, null , "");
}

test "TestDocCommentTemplateReturnsTag1" {
    const content =
        \\/*0*/
        \\function f1() {}
        \\/*1*/
        \\function f2() {
        \\    return 1;
        \\}
        \\/*2*/
        \\const f3 = () => 1;
        \\/*3*/
        \\const f3 = () => {
        \\    return 1;
        \\}
        \\class Foo {
        \\    /*4*/
        \\    m1() {}
        \\
        \\    /*5*/
        \\    m2() {
        \\       return 1;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyJSDocCompletion(undefined, "0", 3, "/** */", null);
    // try f.VerifyJSDocCompletion(undefined, "1", 7, "/**\n * \n * @returns\n */", null);
    // try f.VerifyJSDocCompletion(undefined, "2", 7, "/**\n * \n * @returns\n */", null);
    // try f.VerifyJSDocCompletion(undefined, "3", 7, "/**\n * \n * @returns\n */", null);
    // try f.VerifyJSDocCompletion(undefined, "4", 3, "/** */", null);
    // try f.VerifyJSDocCompletion(undefined, "5", 11, "/**\n     * \n     * @returns\n     */", null);
}

test "TestNavigationBarItemsNamedArrowFunctions" {
    const content =
        \\export const value = 2;
        \\export const func = () => 2;
        \\export const func2 = function() { };
        \\export function exportedFunction() { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestNavigationItemsExportEqualsExpression2" {
    const content =
        \\export const foo = {
        \\  foo: {},
        \\};
        \\
        \\export = {
        \\  foo: {},
        \\};
        \\
        \\export = {
        \\  foo: {},
        \\};
        \\
        \\type Type = typeof foo;
        \\
        \\export = {
        \\  foo: {},
        \\} as Type;
        \\
        \\export = {
        \\  foo: {},
        \\} satisfies Type;
        \\
        \\export = (class {
        \\  prop = 42;
        \\});
        \\
        \\export = (class Cls {
        \\  prop = 42;
        \\});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestFindAllRefsWithLeadingUnderscoreNames6" {
    const content =
        \\class Foo {
        \\    public _bar;
        \\    /*1*/public /*2*/__bar;
        \\    public ___bar;
        \\    public ____bar;
        \\}
        \\
        \\var x: Foo;
        \\x._bar;
        \\x./*3*/__bar;
        \\x.___bar;
        \\x.____bar;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

