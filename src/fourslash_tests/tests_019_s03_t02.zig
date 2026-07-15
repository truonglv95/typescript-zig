const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestInlayHintsInteractiveParameterNames" {
    const content =
        \\ function foo1 (a: number, b: number) {}
        \\ foo1(1, 2);
        \\ function foo2 (a: number, { c }: any) {}
        \\ foo2(1, { c: 1 });
        \\const foo3 = (a = 1) => class { }
        \\const C1 = class extends foo3(1) { }
        \\class C2 extends foo3(1) { }
        \\function foo4(a: number, b: number, c: number, d: number) {}
        \\foo4(1, +1, -1, +"1");
        \\function foo5(
        \\    a: string,
        \\    b: undefined,
        \\    c: null,
        \\    d: boolean,
        \\    e: boolean,
        \\    f: number,
        \\    g: number,
        \\    h: number,
        \\    i: RegExp,
        \\    j: bigint,
        \\) {
        \\}
        \\foo5(
        \\    "hello",
        \\    undefined,
        \\    null,
        \\    true,
        \\    false,
        \\    Infinity,
        \\    -Infinity,
        \\    NaN,
        \\    /hello/g,
        \\    123n,
        \\);
        \\ declare const unknownCall: any;
        \\ unknownCall();
        \\function trace(message: string) {}
        \\trace(
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayParameterNameHints = lsutil.IncludeInlayParameterNameHintsLiterals}});
}

test "TestGetOutliningSpansForRegionsNoSingleLineFolds" {
    const content =
        \\// @lib: es5
        \\[|//#region
        \\function foo()[| {
        \\
        \\}|]
        \\[|//these
        \\//should|]
        \\//#endregion not you|]
        \\[|// be
        \\// together|]
        \\
        \\[|//#region bla bla bla
        \\
        \\function bar()[| { }|]
        \\
        \\//#endregion|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.VerifyOutliningSpans(undefined);
}

test "TestCodeFixClassImplementInterfaceProperty" {
    const content =
        \\// @lib: es2017
        \\enum E { a,b,c }
        \\interface I {
        \\    x: E;
        \\    y: E.a
        \\    z: symbol;
        \\    w: object;
        \\}
        \\class C implements I {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'I'",
        .NewFileContent = "enum E { a,b,c }\ninterface I {\n    x: E;\n    y: E.a\n    z: symbol;\n    w: object;\n}\nclass C implements I {\n    x: E;\n    y: E.a;\n    z: symbol;\n    w: object;\n}",
        .Index = 0,
    });
}

test "TestTsxRename8" {
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
        \\    propx: number
        \\    propString: string
        \\    optional?: boolean
        \\}
        \\declare function Opt(attributes: OptionPropBag): JSX.Element;
        \\let opt = <Opt />;
        \\let opt1 = <Opt propx={100} propString />;
        \\let opt2 = <Opt propx={100} optional/>;
        \\let opt3 = <Opt [|wrong|] />;
        \\let opt4 = <Opt propx={100} propString="hi" />;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRename(undefined, null );
}

test "TestExportInObjectLiteral" {
    const content =
        \\// @Filename: a.ts
        \\const k = {
        \\    [|export|] f() { }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlightsWithOptions(undefined, null , &.{f.Ranges()[0].FileName()}, f.Ranges()[0]);
}

test "TestMemberListOnThisInClassWithPrivates" {
    const content =
        \\class C1 {
        \\   public pubMeth() {this./**/} // test on 'this.'
        \\   private privMeth() {}
        \\   public pubProp = 0;
        \\   private privProp = 0;
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
//                     .Label =  "privMeth",
//                     .Detail = undefined("(method) C1.privMeth(): void"),
//                 },
//                 &.{
//                     .Label =  "privProp",
//                     .Detail = undefined("(property) C1.privProp: number"),
//                 },
//                 &.{
//                     .Label =  "pubMeth",
//                     .Detail = undefined("(method) C1.pubMeth(): void"),
//                 },
//                 &.{
//                     .Label =  "pubProp",
//                     .Detail = undefined("(property) C1.pubProp: number"),
//                 },
//             },
//         },
//     });
}

test "TestFindAllReferencesJSDocFunctionNew" {
    const content =
        \\// @allowJs: true
        \\// @Filename: Foo.js
        \\/** @type {function (/*1*/new: string, string): string} */
        \\var f;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestQuickInfoGetterSetter" {
    const content =
        \\// @target: es2015
        \\class C {
        \\    #x = Promise.resolve("")
        \\    set /*setterDef*/myValue(x: Promise<string> | string) {
        \\        this.#x = Promise.resolve(x);
        \\    }
        \\    get /*getterDef*/myValue(): Promise<string> {
        \\        return this.#x;
        \\    }
        \\}
        \\let instance = new C();
        \\instance./*setterUse*/myValue = instance./*getterUse*/myValue;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "getterUse", "(property) C.myValue: Promise<string>", "");
    // f.VerifyQuickInfoAt(undefined, "getterDef", "(getter) C.myValue: Promise<string>", "");
    // f.VerifyQuickInfoAt(undefined, "setterUse", "(property) C.myValue: string | Promise<string>", "");
    // f.VerifyQuickInfoAt(undefined, "setterDef", "(setter) C.myValue: string | Promise<string>", "");
}

test "TestCallHierarchyCallExpressionByConstNamedFunctionExpression" {
    const content =
        \\function foo() {
        \\    bar();
        \\}
        \\
        \\const bar = function () {
        \\    baz();
        \\}
        \\
        \\function baz() {
        \\}
        \\
        \\/**/bar()
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // f.VerifyBaselineCallHierarchy(undefined);
}

test "TestCompletionsImport_named_exportEqualsNamespace_merged" {
    const content =
        \\// @module: esnext
        \\// @Filename: /b.d.ts
        \\declare namespace N {
        \\    export const foo: number;
        \\}
        \\declare module "n" {
        \\    export = N;
        \\}
        \\// @Filename: /c.d.ts
        \\declare namespace N {}
        \\// @Filename: /a.ts
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
//             .Includes = &.{
//                 &.{
//                     .Label = "foo",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "n",
//                         },
//                     },
//                     .Detail =              undefined("const N.foo: number"),
//                     .Kind =                undefined(lsproto.CompletionItemKindVariable),
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
}

