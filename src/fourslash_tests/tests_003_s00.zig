const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestGoToImplementationInterface_00" {
    const content =
        \\interface Fo/*interface_definition*/o {
        \\    hello: () => void
        \\}
        \\
        \\interface Baz extends Foo {}
        \\
        \\var bar: Foo = [|{|"parts": ["(","object literal",")"], "kind": "interface"|}{ hello: helloImpl /**0*/ }|];
        \\var baz: Foo[] = [|[{ hello: helloImpl /**4*/ }]|];
        \\
        \\function helloImpl () {}
        \\
        \\function whatever(x: Foo = [|{|"parts": ["(","object literal",")"], "kind": "interface"|}{ hello() {/**1*/} }|] ) {
        \\}
        \\
        \\class Bar {
        \\    x: Foo = [|{ hello() {/*2*/} }|]
        \\
        \\    constructor(public f: Foo = [|{ hello() {/**3*/} }|] ) {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToImplementation(undefined, "interface_definition");
}

test "TestCompletionListInTypeParameterOfClassExpression1" {
    const content =
        \\// @lib: es5
        \\var C0 = class D</*0*/
        \\var C1 = class D</*1*/T> {}
        \\var C2 = class D<T, /*2*/
        \\var C3 = class D<T, /*3*/U>{}
        \\var C4 = class D<T extends /*4*/>{}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, &.{"0", "1", "2", "3"}, null);
    // f.VerifyCompletions(undefined, "4", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionGlobalTypesPlus(
//                 &.{
//                     "D",
//                 },
//             ),
//         },
//     });
}

test "TestOrganizeImportsPathsUnicode4" {
    const content =
        \\import * as Ab from "./Ab";
        \\import * as _aB from "./_aB";
        \\import * as aB from "./aB";
        \\import * as _Ab from "./_Ab";
        \\
        \\console.log(_aB, _Ab, aB, Ab);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOrganizeImports(undefined,
//         "import * as _Ab from \"./_Ab\";\nimport * as _aB from \"./_aB\";\nimport * as Ab from \"./Ab\";\nimport * as aB from \"./aB\";\n\nconsole.log(_aB, _Ab, aB, Ab);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSFalse,
//             .OrganizeImportsCollation =  lsutil.OrganizeImportsCollationUnicode,
//             .OrganizeImportsCaseFirst =  lsutil.OrganizeImportsCaseFirstUpper,
//         },
//     );
    // f.VerifyOrganizeImports(undefined,
//         "import * as _aB from \"./_aB\";\nimport * as _Ab from \"./_Ab\";\nimport * as aB from \"./aB\";\nimport * as Ab from \"./Ab\";\n\nconsole.log(_aB, _Ab, aB, Ab);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSFalse,
//             .OrganizeImportsCollation =  lsutil.OrganizeImportsCollationUnicode,
//             .OrganizeImportsCaseFirst =  lsutil.OrganizeImportsCaseFirstLower,
//         },
//     );
}

test "TestImportNameCodeFix_barrelExport2" {
    const content =
        \\// @module: commonjs
        \\// @baseUrl: /
        \\// @Filename: /proj/foo/a.ts
        \\export const A = 0;
        \\// @Filename: /proj/foo/b.ts
        \\export {};
        \\A/*sibling*/
        \\// @Filename: /proj/foo/index.ts
        \\export * from "./a";
        \\export * from "./b";
        \\// @Filename: /proj/index.ts
        \\export * from "./foo";
        \\export * from "./src";
        \\// @Filename: /proj/src/a.ts
        \\export {};
        \\A/*parent*/
        \\// @Filename: /proj/src/utils.ts
        \\export function util() { return "util"; }
        \\export { A } from "../foo/a";
        \\// @Filename: /proj/src/index.ts
        \\export * from "./a";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyImportFixModuleSpecifiers(undefined, "sibling", &.{"proj/foo/a", "proj/src/utils", "proj", "proj/foo"}, &.{.ImportModuleSpecifierPreference = "non-relative"});
    // f.VerifyImportFixModuleSpecifiers(undefined, "parent", &.{"proj/foo", "proj/foo/a", "proj/src/utils", "proj"}, &.{.ImportModuleSpecifierPreference = "non-relative"});
}

test "TestQuickInfoOnPropDeclaredUsingIndexSignatureOnInterfaceWithBase" {
    const content =
        \\interface P {}
        \\interface B extends P {
        \\  [k: string]: number;
        \\}
        \\declare const b: B;
        \\b.t/*1*/est = 10;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "(index) B[string]: number", "");
}

test "TestGoToDefinitionJsModuleNameAtImportName" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /foo.js
        \\ /*moduleDef*/function notExported() { }
        \\ class Blah {
        \\    abc = 123;
        \\ }
        \\ module.exports.Blah = Blah;
        \\// @Filename: /bar.js
        \\const [|/*importDef*/BlahModule|] = require("./foo.js");
        \\new [|/*importUsage*/BlahModule|].Blah()
        \\// @Filename: /barTs.ts
        \\import [|/*importDefTs*/BlahModule|] = require("./foo.js");
        \\new [|/*importUsageTs*/BlahModule|].Blah()
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "importDef", "importUsage", "importDefTs", "importUsageTs");
}

test "TestImportStatementCompletions_js" {
    const content =
        \\// @allowJs: true
        \\// @target: es2020
        \\// @checkJs: true
        \\// @module: commonjs
        \\// @noEmit: true
        \\// @allowSyntheticDefaultImports: true
        \\// @Filename: /node_modules/react/index.d.ts
        \\declare namespace React {
        \\   export class Component {}
        \\}
        \\export = React;
        \\// @Filename: /test.js
        \\[|import R/**/|]
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
//                     .Label =      "React",
//                     .InsertText = undefined("import React$1 from \"react\";"),
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "react",
//                         },
//                     },
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "React",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestGetOccurrencesTryCatchFinally" {
    const content =
        \\/*1*/[|try|] {
        \\    try {
        \\    }
        \\    catch (x) {
        \\    }
        \\
        \\    try {
        \\    }
        \\    finally {
        \\    }
        \\}
        \\[|cat/*2*/ch|] (e) {
        \\}
        \\[|fina/*3*/lly|] {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Markers()));
}

test "TestInlayHintsPropertyDeclarations" {
    const content =
        \\// @strict: true
        \\class C {
        \\    a = 1
        \\    b: number = 2
        \\    c;
        \\    d;
        \\
        \\    constructor(value: number) {
        \\        this.d = value;
        \\        if (value <= 0) {
        \\            this.d = null;
        \\        }
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayPropertyDeclarationTypeHints = core.TSTrue}});
}

test "TestGoToDefinitionImport3" {
    const content =
        \\// @Filename: /b.ts
        \\/*2*/export const foo = 1;
        \\// @Filename: /a.ts
        \\import { foo } [|from     /*1*/|] "./b";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestFormattingTemplates" {
    const content =
        \\String.call 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, ";");
    _ = f.VerifyCurrentLineContent(undefined, "String.call`${123}`;");
    _ = f.GoToMarker(undefined, "2");
    _ = f.Insert(undefined, ";");
    _ = f.VerifyCurrentLineContent(undefined, "String.call`${123} ${456}`;");
}

test "TestFindAllReferencesOfJsonModule" {
    const content =
        \\// @resolveJsonModule: true
        \\// @module: commonjs
        \\// @esModuleInterop: true
        \\// @Filename: /foo.ts
        \\/*1*/import /*2*/settings from "./settings.json";
        \\/*3*/settings;
        \\// @Filename: /settings.json
        \\ {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestRemoveParameterBetweenCommentAndParameter" {
    const content =
        \\function fn(/* comment! */ /**/a: number, c) { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.DeleteAtCaret(undefined, 10);
}

test "TestCompletionsImport_typeOnly" {
    const content =
        \\// @target: esnext
        \\// @moduleResolution: bundler
        \\// @Filename: /a.ts
        \\export class A {}
        \\export class B {}
        \\// @Filename: /b.ts
        \\import type { A } from './a';
        \\const b: B/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/b.ts");
    // f.VerifyApplyCodeActionFromCompletion(undefined, undefined(""), &.{
//         .Name =        "B",
//         .Source =      "./a",
//         .Description = "Update import from \"./a\"",
//         .NewFileContent = undefined("import type { A, B } from './a';\nconst b: B"),
//     });
}

test "TestFunduleWithRecursiveReference" {
    const content =
        \\namespace M {
        \\    export function C() {}
        \\    export namespace C {
        \\    export var /**/C = M.C
        \\  }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "var M.C.C: typeof M.C", "");
    _ = f.VerifyNoErrors(undefined);
}

test "TestQuickInfoForObjectBindingElementName04" {
    const content =
        \\interface Options {
        \\   /**
        \\    * A description of 'a'
        \\    */
        \\    a: {
        \\       /**
        \\        * A description of 'b'
        \\        */
        \\       b: string;
        \\   }
        \\}
        \\
        \\function f({ a, a: { b } }: Options) {
        \\    a/*1*/;
        \\    b/*2*/;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestTsxSignatureHelp2" {
    const content =
        \\// @jsx: preserve
        \\//@Filename: file.tsx
        \\import React = require('react');
        \\export interface ClickableProps {
        \\    children?: string;
        \\    className?: string;
        \\}
        \\export interface ButtonProps extends ClickableProps {
        \\    onClick(event?: React.MouseEvent<HTMLButtonElement>): void;
        \\}
        \\export interface LinkProps extends ClickableProps {
        \\    goTo(where: "home" | "contact"): void;
        \\}
        \\function _buildMainButton({ onClick, children, className }: ButtonProps): JSX.Element {
        \\    return(<button className={className} onClick={onClick}>{ children || 'MAIN BUTTON'}</button>);
        \\}
        \\export function MainButton(buttonProps: ButtonProps): JSX.Element;
        \\export function MainButton(linkProps: LinkProps): JSX.Element;
        \\export function MainButton(props: ButtonProps | LinkProps): JSX.Element {
        \\    return this._buildMainButton(props);
        \\}
        \\let e1 = <MainButton/*1*/ /*2*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // f.VerifySignatureHelp(undefined, .{.Text = "MainButton(buttonProps: ButtonProps): JSX.Element", .ParameterSpan = "buttonProps: ButtonProps", .OverloadsCount = 2});
    _ = f.GoToMarker(undefined, "2");
    // f.VerifySignatureHelp(undefined, .{.Text = "MainButton(buttonProps: ButtonProps): JSX.Element", .ParameterSpan = "buttonProps: ButtonProps", .OverloadsCount = 2});
}

test "TestQuickInfoJSDocTags" {
    const content =
        \\/**
        \\ * This is class Foo.
        \\ * @mytag comment1 comment2
        \\ */
        \\class Foo {
        \\    /**
        \\     * This is the constructor.
        \\     * @myjsdoctag this is a comment
        \\     */
        \\    constructor(value: number) {}
        \\    /**
        \\     * method1 documentation
        \\     * @mytag comment1 comment2
        \\     */
        \\    static method1() {}
        \\    /**
        \\     * @mytag
        \\     */
        \\    method2() {}
        \\    /**
        \\     * @mytag comment1 comment2
        \\     */
        \\    property1: string;
        \\    /**
        \\     * @mytag1 some comments
        \\     * some more comments about mytag1
        \\     * @mytag2
        \\     * here all the comments are on a new line
        \\     * @mytag3
        \\     * @mytag
        \\     */
        \\    property2: number;
        \\    /**
        \\     * @returns {number} a value
        \\     */
        \\    method3(): number { return 3; }
        \\    /**
        \\     * @param {string} foo A value.
        \\     * @returns {number} Another value
        \\     * @mytag
        \\     */
        \\    method4(foo: string): number { return 3; }
        \\    /** @mytag */
        \\    method5() {}
        \\    /** method documentation
        \\     *  @mytag a JSDoc tag
        \\     */
        \\    newMethod() {}
        \\}
        \\var foo = new /*1*/Foo(/*10*/4);
        \\/*2*/Foo./*3*/method1(/*11*/);
        \\foo./*4*/method2(/*12*/);
        \\foo./*5*/method3(/*13*/);
        \\foo./*6*/method4();
        \\foo./*7*/property1;
        \\foo./*8*/property2;
        \\foo./*9*/method5();
        \\foo.newMet/*14*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestUnusedImports6FS" {
    const content =
        \\// @noUnusedLocals: true
        \\// @Filename: file2.ts
        \\[| import d from "./file1" |]
        \\// @Filename: file1.ts
        \\export class Calculator {
        \\    handleChar() { }
        \\}
        \\export function test() {
        \\
        \\}
        \\export default function test2() {
        \\
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyRangeAfterCodeFix(undefined, "", false, 0, 0);
}

test "TestFindAllReferencesJSDocFunctionThis" {
    const content =
        \\// @allowJs: true
        \\// @Filename: Foo.js
        \\/** @type {function (this: string, string): string} */
        \\var f = function (s) { return /*0*/this + s; }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "0");
}

test "TestQuickInfoInFunctionTypeReference2" {
    const content =
        \\class C<T> {
        \\    map(fn: (/*1*/k: string, /*2*/value: T, context: any) => void, context: any) {
        \\    }
        \\}
        \\var c: C<number>;
        \\c.map(/*3*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "(parameter) k: string", "");
    // f.VerifyQuickInfoAt(undefined, "2", "(parameter) value: T", "");
    _ = f.GoToMarker(undefined, "3");
    // f.VerifySignatureHelp(undefined, .{.Text = "map(fn: (k: string, value: number, context: any) => void, context: any): void"});
}

test "TestAutoImportModuleNone2" {
    const content =
        \\// @module: none
        \\// @moduleResolution: bundler
        \\// @target: es2015
        \\// @Filename: /node_modules/dep/index.d.ts
        \\export const x: number;
        \\// @Filename: /index.ts
        \\ x/**/
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
//                     .Label = "x",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "dep",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
    _ = f.ReplaceLine(undefined, 0, "import { x } from 'dep'; x;");
    _ = f.VerifyNonSuggestionDiagnostics(undefined, null);
}

test "TestQuickInfoUnion_discriminated" {
    const content =
        \\// @Filename: quickInfoJsDocTags.ts
        \\type U = A | B;
        \\
        \\interface A {
        \\    /** Kind A */
        \\    kind: "a";
        \\    /** Prop A */
        \\    prop: number;
        \\}
        \\
        \\interface B {
        \\    /** Kind B */
        \\    kind: "b";
        \\    /** Prop B */
        \\    prop: string;
        \\}
        \\
        \\const u: U = {
        \\    /*uKind*/kind: "a",
        \\    /*uProp*/prop: 0,
        \\}
        \\const u2: U = {
        \\    /*u2Kind*/kind: "bogus",
        \\    /*u2Prop*/prop: 1,
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "uKind", "(property) A.kind: \"a\"", "Kind A");
    // f.VerifyQuickInfoAt(undefined, "uProp", "(property) A.prop: number", "Prop A");
    // f.VerifyQuickInfoAt(undefined, "u2Kind", "(property) kind: \"bogus\"", "");
    // f.VerifyQuickInfoAt(undefined, "u2Prop", "(property) prop: number", "");
}

test "TestCodeFixCorrectReturnValue5" {
    const content =
        \\function Foo (): void {
        \\    undefined
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCodeFixNotAvailable(undefined);
}

test "TestQuickinfoVerbosityTuple" {
    const content =
        \\interface Orange {
        \\    color: string;
        \\}
        \\interface Apple {
        \\    color: string;
        \\    other: Orange;
        \\}
        \\type TwoFruits/*T*/ = [Orange, Apple];
        \\const tf/*f*/: TwoFruits = [
        \\    { color: "orange" },
        \\    { color: "red", other: { color: "orange" } }
        \\];
        \\const tf2/*f2*/: [Orange, Apple] = [
        \\    { color: "orange" },
        \\    { color: "red", other: { color: "orange" } }
        \\];
        \\type ManyFruits/*m*/ = (Orange | Apple)[];
        \\const mf/*mf*/: ManyFruits = [];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"T" = .{0, 1, 2}, .@"f" = .{0, 1, 2, 3}, .@"f2" = .{0, 1, 2}, .@"m" = .{0, 1, 2}, .@"mf" = .{0, 1, 2, 3}});
}

test "TestNavigationBarAnonymousClassAndFunctionExpressions" {
    const content =
        \\global.cls = class { };
        \\(function() {
        \\    const x = () => {
        \\        // Presence of inner function causes x to be a top-level function.
        \\        function xx() {}
        \\    };
        \\    const y = {
        \\        // This is not a top-level function (contains nothing, but shows up in childItems of its parent.)
        \\        foo: function() {}
        \\    };
        \\    (function nest() {
        \\        function moreNest() {}
        \\    })();
        \\})();
        \\(function() { // Different anonymous functions are not merged
        \\    // These will only show up as childItems.
        \\    function z() {}
        \\    console.log(function() {})
        \\    describe("this", 'function', 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestQuickInfoDisplayPartsClassAccessors" {
    const content =
        \\class c {
        \\    public get /*1*/publicProperty() { return ""; }
        \\    public set /*1s*/publicProperty(x: string) { }
        \\    private get /*2*/privateProperty() { return ""; }
        \\    private set /*2s*/privateProperty(x: string) { }
        \\    protected get /*21*/protectedProperty() { return ""; }
        \\    protected set /*21s*/protectedProperty(x: string) { }
        \\    static get /*3*/staticProperty() { return ""; }
        \\    static set /*3s*/staticProperty(x: string) { }
        \\    private static get  /*4*/privateStaticProperty() { return ""; }
        \\    private static set /*4s*/privateStaticProperty(x: string) { }
        \\    protected static get /*41*/protectedStaticProperty() { return ""; }
        \\    protected static set /*41s*/protectedStaticProperty(x: string) { }
        \\    method() {
        \\        var x : string;
        \\        x = this./*5*/publicProperty;
        \\        x = this./*6*/privateProperty;
        \\        x = this./*61*/protectedProperty;
        \\        x = c./*7*/staticProperty;
        \\        x = c./*8*/privateStaticProperty;
        \\        x = c./*81*/protectedStaticProperty;
        \\        this./*5s*/publicProperty = "";
        \\        this./*6s*/privateProperty = "";
        \\        this./*61s*/protectedProperty = "";
        \\        c./*7s*/staticProperty = "";
        \\        c./*8s*/privateStaticProperty = "";
        \\        c./*81s*/protectedStaticProperty = "";
        \\    }
        \\}
        \\var cInstance = new c();
        \\var y: string;
        \\y = /*9*/cInstance./*10*/publicProperty;
        \\y = /*11*/c./*12*/staticProperty;
        \\/*9s*/cInstance./*10s*/publicProperty = y;
        \\/*11s*/c./*12s*/staticProperty = y;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestAutoImportTypeOnlyPreferred1" {
    const content =
        \\// @verbatimModuleSyntax: true
        \\// @module: esnext
        \\// @moduleResolution: bundler
        \\// @Filename: /ts.d.ts
        \\declare namespace ts {
        \\  interface SourceFile {
        \\      text: string;
        \\  }
        \\  function createSourceFile(): SourceFile;
        \\}
        \\export = ts;
        \\// @Filename: /types.ts
        \\export interface VFS {
        \\  getSourceFile(path: string): ts/**/
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
//                     .Label = "ts",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./ts",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
}

test "TestRenameObjectSpreadAssignment" {
    const content =
        \\interface A1 { a: number };
        \\interface A2 { a?: number };
        \\[|let [|{| "contextRangeIndex": 0 |}a1|]: A1;|]
        \\[|let [|{| "contextRangeIndex": 2 |}a2|]: A2;|]
        \\let a12 = { ...[|a1|], ...[|a2|] };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRename(undefined, null , f.Ranges()[1], f.Ranges()[4], f.Ranges()[3], f.Ranges()[5]);
}

test "TestQuickInfoMappedTypeRecursiveInference" {
    const content =
        \\// @Filename: test.ts
        \\interface A { a: A }
        \\declare let a: A;
        \\type Deep<T> = { [K in keyof T]: Deep<T[K]> }
        \\declare function foo<T>(deep: Deep<T>): T;
        \\const out/*1*/ = foo/*2*/(a);
        \\out.a/*3*/
        \\out.a.a/*4*/
        \\out.a.a.a.a.a.a.a/*5*/
        \\
        \\interface B { [s: string]: B }
        \\declare let b: B;
        \\const oub/*6*/ = foo/*7*/(b);
        \\oub.b/*8*/
        \\oub.b.b/*9*/
        \\oub.b.a.n.a.n.a/*10*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "const out: {\n    a: {\n        a: ...;\n    };\n}", "");
    // f.VerifyQuickInfoAt(undefined, "2", "function foo<{\n    a: {\n        a: ...;\n    };\n}>(deep: Deep<{\n    a: {\n        a: ...;\n    };\n}>): {\n    a: {\n        a: ...;\n    };\n}", "");
    // f.VerifyQuickInfoAt(undefined, "3", "(property) a: {\n    a: {\n        a: ...;\n    };\n}", "");
    // f.VerifyQuickInfoAt(undefined, "4", "(property) a: {\n    a: {\n        a: ...;\n    };\n}", "");
    // f.VerifyQuickInfoAt(undefined, "5", "(property) a: {\n    a: {\n        a: ...;\n    };\n}", "");
    // f.VerifyQuickInfoAt(undefined, "6", "const oub: {\n    [x: string]: ...;\n}", "");
    // f.VerifyQuickInfoAt(undefined, "7", "function foo<{\n    [x: string]: ...;\n}>(deep: Deep<{\n    [x: string]: ...;\n}>): {\n    [x: string]: ...;\n}", "");
    // f.VerifyQuickInfoAt(undefined, "8", "{\n    [x: string]: ...;\n}", "");
    // f.VerifyQuickInfoAt(undefined, "9", "{\n    [x: string]: ...;\n}", "");
    // f.VerifyQuickInfoAt(undefined, "10", "{\n    [x: string]: ...;\n}", "");
}

test "TestGetJavaScriptSyntacticDiagnostics9" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\public function F() { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineNonSuggestionDiagnostics(undefined);
}

test "TestCodeFixMissingTypeAnnotationOnExports43_expando_functions_3" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\// @lib: es2019
        \\// @Filename: /code.ts
        \\function foo(): void {}
        \\foo.x = 1;
        \\foo.y = 1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Annotate types of properties expando function in a namespace",
        .NewFileContent = "function foo(): void {}\ndeclare namespace foo {\n    export var x: number;\n    export var y: number;\n}\nfoo.x = 1;\nfoo.y = 1;",
        .Index = 0,
    });
}

test "TestSyntacticClassificationsTemplates2" {
    const content =
        \\var tiredOfCanonicalExamples =
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "variable.declaration", .Text = "tiredOfCanonicalExamples"},
//     });
}

test "TestFormattingKeywordAsIdentifier" {
    const content =
        \\declare var module/*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, ";");
    _ = f.VerifyCurrentLineContent(undefined, "declare var module;");
}

test "TestJsDocAugmentsAndExtends" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: dummy.js
        \\/**
        \\ * @augments {Thing<number>}
        \\ * [|@extends {Thing<string>}|]
        \\ */
        \\class MyStringThing extends Thing {
        \\    constructor() {
        \\        super();
        \\        var x = this.mine;
        \\        x/**/;
        \\    }
        \\}
        \\// @Filename: declarations.d.ts
        \\declare class Thing<T> {
        \\    mine: T;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyQuickInfoIs(undefined, "(local var) x: number", "");
    // f.VerifyNonSuggestionDiagnostics(undefined, []*.{
//         .{
//             .Message = .{.String = undefined("Class declarations cannot have more than one '@augments' or '@extends' tag.")},
//             .Code =    &.{.Integer = undefined(int32(8025))},
//         },
//     });
}

test "TestErrorInIncompleteMethodInObjectLiteral" {
    const content =
        \\var x: { f(): string } = { f( }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
}

test "TestGoToTypeDefinitionImportMeta" {
    const content =
        \\// @lib: es5
        \\// @module: esnext
        \\// @Filename: foo.ts
        \\/// <reference path='./bar.d.ts' />
        \\import.me/*reference*/ta;
        \\//@Filename: bar.d.ts
        \\interface /*definition*/ImportMeta {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToTypeDefinition(undefined, "reference");
}

test "TestCodeFixMissingTypeAnnotationOnExports44_default_export" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\// @lib: es2019
        \\// @Filename: /code.ts
        \\export default 1 + 1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Extract default export to variable",
        .NewFileContent = "const _default_1: number = 1 + 1;\nexport default _default_1;",
        .Index = 0,
    });
}

test "TestJsdocSatisfiesTagCompletion1" {
    const content =
        \\// @lib: es5
        \\// @noEmit: true
        \\// @allowJS: true
        \\// @checkJs: true
        \\// @filename: /a.js
        \\/**
        \\ * @satisfies {/**/}
        \\ */
        \\const t = { a: 1 };
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
//             .Exact = CompletionGlobalTypes,
//         },
//     });
}

test "TestRenameBindingElementInitializerProperty" {
    const content =
        \\function f([|{[|{| "contextRangeIndex": 0 |}required|], optional = [|required|]}: {[|[|{| "contextRangeIndex": 3 |}required|]: number,|] optional?: number}|]) {
        \\    console.log("required", [|required|]);
        \\    console.log("optional", optional);
        \\}
        \\
        \\f({[|[|{| "contextRangeIndex": 6 |}required|]: 10|]});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRename(undefined, null , f.Ranges()[1], f.Ranges()[2], f.Ranges()[5], f.Ranges()[4], f.Ranges()[7]);
}

test "TestCompletionsImport_addToNamedWithDifferentCacheValue" {
    const content =
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{ "compilerOptions": { "module": "commonjs", "lib": ["es5"] } }
        \\// @Filename: /home/src/workspaces/project/packages/mylib/package.json
        \\{ "name": "mylib", "version": "1.0.0", "main": "index.js" }
        \\// @Filename: /home/src/workspaces/project/packages/mylib/index.ts
        \\export * from "./mySubDir";
        \\// @Filename: /home/src/workspaces/project/packages/mylib/mySubDir/index.ts
        \\export * from "./myClass";
        \\export * from "./myClass2";
        \\// @Filename: /home/src/workspaces/project/packages/mylib/mySubDir/myClass.ts
        \\export class MyClass {}
        \\// @Filename: /home/src/workspaces/project/packages/mylib/mySubDir/myClass2.ts
        \\export class MyClass2 {}
        \\// @link: /home/src/workspaces/project/packages/mylib -> /home/src/workspaces/project/node_modules/mylib
        \\// @Filename: /home/src/workspaces/project/src/index.ts
        \\
        \\const a = new MyClass/*1*/();
        \\const b = new MyClass2/*2*/();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToMarker(undefined, "1");
    // f.GetOptions();
    // f.Configure(undefined, opts1267);
    // f.VerifyCompletions(undefined, "1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label = "MyClass",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "../packages/mylib",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
    // f.VerifyApplyCodeActionFromCompletion(undefined, undefined("1"), &.{
//         .Name =          "MyClass",
//         .Source =        "../packages/mylib",
//         .Description =   "Add import from \"../packages/mylib\"",
//         .AutoImportFix = &.{},
//         .NewFileContent = undefined("import { MyClass } from \"../packages/mylib\";\n\nconst a = new MyClass();\nconst b = new MyClass2();"),
//     });
    _ = f.ReplaceLine(undefined, 0, "import { MyClass } from \"mylib\";");
    // f.VerifyCompletions(undefined, "2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label = "MyClass2",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "mylib",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
}

test "TestGoToSource12_callbackParam" {
    const content =
        \\// @lib: es5
        \\// @moduleResolution: bundler
        \\// @Filename: /home/src/workspaces/project/node_modules/@types/yargs/package.json
        \\{
        \\    "name": "@types/yargs",
        \\    "version": "1.0.0",
        \\    "types": "./index.d.ts"
        \\}
        \\// @Filename: /home/src/workspaces/project/node_modules/@types/yargs/index.d.ts
        \\export interface Yargs { positional(): Yargs; }
        \\export declare function command(command: string, cb: (yargs: Yargs) => void): void;
        \\// @Filename: /home/src/workspaces/project/node_modules/yargs/package.json
        \\{
        \\    "name": "yargs",
        \\    "version": "1.0.0",
        \\    "main": "index.js"
        \\}
        \\// @Filename: /home/src/workspaces/project/node_modules/yargs/index.js
        \\export function command(cmd, cb) { cb({ /*end*/positional: "This is obviously not even close to realistic" }); }
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\import { command } from "yargs";
        \\command("foo", yargs => {
        \\    yargs.[|/*start*/positional|]();
        \\});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.VerifyBaselineGoToSourceDefinition(undefined, "start");
}

test "TestReferencesForDeclarationKeywords" {
    const content =
        \\class Base {}
        \\interface Implemented1 {}
        \\/*classDecl1_classKeyword*/class C1 /*classDecl1_extendsKeyword*/extends Base /*classDecl1_implementsKeyword*/implements Implemented1 {
        \\    /*getDecl_getKeyword*/get e() { return 1; }
        \\    /*setDecl_setKeyword*/set e(v) {}
        \\}
        \\/*interfaceDecl1_interfaceKeyword*/interface I1 /*interfaceDecl1_extendsKeyword*/extends Base { }
        \\/*typeDecl_typeKeyword*/type T = { }
        \\/*enumDecl_enumKeyword*/enum E { }
        \\/*namespaceDecl_namespaceKeyword*/namespace N { }
        \\/*moduleDecl_moduleKeyword*/namespace M { }
        \\/*functionDecl_functionKeyword*/function fn() {}
        \\/*varDecl_varKeyword*/var x;
        \\/*letDecl_letKeyword*/let y;
        \\/*constDecl_constKeyword*/const z = 1;
        \\interface Implemented2 {}
        \\interface Implemented3 {}
        \\class C2 /*classDecl2_implementsKeyword*/implements Implemented2, Implemented3 {}
        \\interface I2 /*interfaceDecl2_extendsKeyword*/extends Implemented2, Implemented3 {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "classDecl1_classKeyword", "classDecl1_extendsKeyword", "classDecl1_implementsKeyword", "classDecl2_implementsKeyword", "getDecl_getKeyword", "setDecl_setKeyword", "interfaceDecl1_interfaceKeyword", "interfaceDecl1_extendsKeyword", "interfaceDecl2_extendsKeyword", "typeDecl_typeKeyword", "enumDecl_enumKeyword", "namespaceDecl_namespaceKeyword", "moduleDecl_moduleKeyword", "functionDecl_functionKeyword", "varDecl_varKeyword", "letDecl_letKeyword", "constDecl_constKeyword");
}

test "TestCompletionListInstanceProtectedMembers4" {
    const content =
        \\class Base {
        \\    private privateMethod() { }
        \\    private privateProperty;
        \\
        \\    protected protectedMethod() { }
        \\    protected protectedProperty;
        \\
        \\    public publicMethod() { }
        \\    public publicProperty;
        \\
        \\    protected protectedOverriddenMethod() { }
        \\    protected protectedOverriddenProperty;
        \\}
        \\
        \\class C1 extends Base {
        \\    public protectedOverriddenMethod() { }
        \\    public protectedOverriddenProperty;
        \\}
        \\
        \\ var c: C1;
        \\ c./*1*/
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
//                 "protectedOverriddenMethod",
//                 "protectedOverriddenProperty",
//                 "publicMethod",
//                 "publicProperty",
//             },
//         },
//     });
}

test "TestLinkedEditingJsxTag8" {
    const content =
        \\// @FileName: /mismatchedNames.tsx
        \\const A = thing;
        \\const B = thing;
        \\const jsx = (
        \\    </*8*/A>
        \\    </B>
        \\);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyLinkedEditing(undefined, .{
//         .@"8" = null,
//     });
}

test "TestCompletionsWithOptionalPropertiesGenericPartial3" {
    const content =
        \\// @strict: true
        \\interface Foo {
        \\  a: boolean;
        \\}
        \\function partialFoo<T extends Partial<Foo>>(x: T, y: T extends { b?: boolean } ? T & { c: true } : T) {
        \\  return x;
        \\}
        \\
        \\partialFoo({ a: true, b: true }, { /*1*/ });
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
//                     .Label =      "a?",
//                     .InsertText = undefined("a"),
//                     .FilterText = undefined("a"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//                 &.{
//                     .Label =      "b?",
//                     .InsertText = undefined("b"),
//                     .FilterText = undefined("b"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//                 &.{
//                     .Label = "c",
//                 },
//             },
//         },
//     });
}

test "TestImportNameCodeFix_require_addToExisting" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: blah.js
        \\export default class Blah {}
        \\export const Named1 = 0;
        \\export const Named2 = 1;
        \\// @Filename: index.js
        \\var path = require('path')
        \\  , { promisify } = require('util')
        \\  , { Named1 } = require('./blah')
        \\
        \\new Blah
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "index.js");
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Update import from \"./blah\"",
        .NewFileContent = "var path = require('path')\n  , { promisify } = require('util')\n  , { Named1, default: Blah } = require('./blah')\n\nnew Blah",
        .Index = 0,
    });
}

test "TestReferencesForLabel6" {
    const content =
        \\/*1*/labela: while (true) {
        \\/*2*/labelb:     while (false) { /*3*/break /*4*/labelb; }
        \\            break labelc;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestCompletionForStringLiteral2" {
    const content =
        \\var o = {
        \\    foo() { },
        \\    bar: 0,
        \\    "some other name": 1
        \\};
        \\declare const p: { [s: string]: any, a: number };
        \\
        \\o["[|/*1*/bar|]"];
        \\o["/*2*/ ;
        \\p["[|/*3*/|]"];
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
//                     .Label = "bar",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "bar",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label = "foo",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "foo",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label = "some other name",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "some other name",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
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
//                 "bar",
//                 "foo",
//                 "some other name",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "3", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label = "a",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "a",
//                             .Range =   f.Ranges()[1].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestInlayHintsFunctionParameterTypes5" {
    const content =
        \\declare const STATE_SIGNAL: unique symbol;
        \\
        \\declare function test(
        \\  cb: (state: { [STATE_SIGNAL]: unknown }) => void,
        \\): unknown;
        \\
        \\test((state) => {});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayFunctionParameterTypeHints = core.TSTrue}});
}

