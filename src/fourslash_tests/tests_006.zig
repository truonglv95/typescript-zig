const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestOverloadObjectLiteralCrash" {
    const content =
        \\interface Foo {
        \\    extend<T>(...objs: any[]): T;
        \\    extend<T>(deep, target: T): T;
        \\}
        \\var $: Foo;
        \\$.extend({ /**/foo: 0 }, "");
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyQuickInfoExists(undefined);
}

test "TestTsxCompletion2" {
    const content =
        \\//@Filename: file.tsx
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\    }
        \\    interface ElementAttributesProperty { props; }
        \\}
        \\class MyComp { props: { ONE: string; TWO: number } }
        \\var x = <MyComp /**//>;
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
//                 "ONE",
//                 "TWO",
//             },
//         },
//     });
}

test "TestTsxQuickInfo4" {
    const content =
        \\//@Filename: file.tsx
        \\// @jsx: preserve
        \\// @noLib: true
        \\export interface ClickableProps {
        \\    children?: string;
        \\    className?: string;
        \\}
        \\export interface ButtonProps extends ClickableProps {
        \\    onClick(event?: React.MouseEvent<HTMLButtonElement>): void;
        \\}
        \\export interface LinkProps extends ClickableProps {
        \\    to: string;
        \\}
        \\export function MainButton(buttonProps: ButtonProps): JSX.Element;
        \\export function MainButton(linkProps: LinkProps): JSX.Element;
        \\export function MainButton(props: ButtonProps | LinkProps): JSX.Element {
        \\    const linkProps = props as LinkProps;
        \\    if(linkProps.to) {
        \\        return this._buildMainLink(props);
        \\    }
        \\    return this._buildMainButton(props);
        \\}
        \\function _buildMainButton({ onClick, children, className }: ButtonProps): JSX.Element {
        \\    return(<button className={className} onClick={onClick}>{ children || 'MAIN BUTTON'}</button>);
        \\}
        \\declare function buildMainLink({ to, children, className }: LinkProps): JSX.Element;
        \\function buildSomeElement1(): JSX.Element {
        \\    return (
        \\        <MainB/*1*/utton t/*2*/o='/some/path'>GO</MainButton>
        \\    );
        \\}
        \\function buildSomeElement2(): JSX.Element {
        \\    return (
        \\        <MainB/*3*/utton onC/*4*/lick={()=>{}}>GO</MainButton>;
        \\    );
        \\}
        \\let componenet = <MainButton onClick={()=>{}} ext/*5*/ra-prop>GO</MainButton>;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "function MainButton(linkProps: LinkProps): JSX.Element (+1 overload)", "");
    try f.VerifyQuickInfoAt(undefined, "2", "(property) LinkProps.to: string", "");
    try f.VerifyQuickInfoAt(undefined, "3", "function MainButton(buttonProps: ButtonProps): JSX.Element (+1 overload)", "");
    try f.VerifyQuickInfoAt(undefined, "4", "(method) ButtonProps.onClick(event?: React.MouseEvent<HTMLButtonElement>): void", "");
    try f.VerifyQuickInfoAt(undefined, "5", "(property) extra-prop: true", "");
}

test "TestGetOccurrencesSwitchCaseDefault2" {
    const content =
        \\switch (10) {
        \\    case 1:
        \\    case 2:
        \\    case 4:
        \\    case 8:
        \\        foo: [|switch|] (20) {
        \\            [|case|] 1:
        \\            [|case|] 2:
        \\                [|break|];
        \\            [|default|]:
        \\                [|break|] foo;
        \\        }
        \\    case 0xBEEF:
        \\    default:
        \\        break;
        \\    case 16:
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestCompletionsDestructuring" {
    const content =
        \\const points = [{ x: 1, y: 2 }];
        \\points.forEach(({ /*a*/ }) => { });
        \\const { /*b*/ } = points[0];
        \\for (const { /*c*/ } of points) {}
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
//                 "x",
//                 "y",
//             },
//         },
//     });
}

test "TestDocumentHighlightMultilineTemplateStrings" {
    const content =
        \\const foo = 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , f.Ranges()[0]);
}

test "TestReferencesForGlobals" {
    const content =
        \\// @Filename: referencesForGlobals_1.ts
        \\/*1*/var /*2*/global = 2;
        \\
        \\class foo {
        \\    constructor (public global) { }
        \\    public f(global) { }
        \\    public f2(global) { }
        \\}
        \\
        \\class bar {
        \\    constructor () {
        \\        var n = /*3*/global;
        \\
        \\        var f = new foo('');
        \\        f.global = '';
        \\    }
        \\}
        \\
        \\var k = /*4*/global;
        \\// @Filename: referencesForGlobals_2.ts
        \\var m = /*5*/global;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5");
}

test "TestCompletionsImportYieldExpression" {
    const content =
        \\// @Filename: /a.ts
        \\export function a() {}
        \\// @Filename: /b.ts
        \\function *f() {
        \\  yield a/**/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyApplyCodeActionFromCompletion(undefined, undefined(""), &.{
//         .Name =        "a",
//         .Source =      "./a",
//         .Description = "Add import from \"./a\"",
//         .NewFileContent = undefined("import { a } from \"./a\";\n\nfunction *f() {\n  yield a\n}"),
//     });
}

test "TestInlayHintsInteractiveVariableTypes2" {
    const content =
        \\const object = { foo: 1, bar: 2 }
        \\const array = [1, 2]
        \\const a = object;
        \\const { foo, bar } = object;
        \\const {} = object;
        \\const b = array;
        \\const [ first, second ] = array;
        \\const [] = array;
        \\declare function foo<T extends number>(t: T): T
        \\const x = foo(1)
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayVariableTypeHints = core.TSTrue}});
}

test "TestFormattingOnEnterInComments" {
    const content =
        \\namespace me {
        \\    class A {
        \\        /*
        \\         */*1*/
        \\    /*2*/}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.InsertLine(undefined, "");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyCurrentLineContent(undefined, "    }");
}

test "TestQuickInfoForContextuallyTypedIife" {
    const content =
        \\(({ q/*1*/, qq/*2*/ }, x/*3*/, { p/*4*/ }) => {
        \\    var s: number = q/*5*/;
        \\    var t: number = qq/*6*/;
        \\    var u: number = p/*7*/;
        \\    var v: number = x/*8*/;
        \\    return q; })({ q: 13, qq: 12 }, 1, { p: 14 });
        \\((a/*9*/, b/*10*/, c/*11*/) => [a/*12*/,b/*13*/,c/*14*/])("foo", 101, false);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "(parameter) q: number", "");
    try f.VerifyQuickInfoAt(undefined, "2", "(parameter) qq: number", "");
    try f.VerifyQuickInfoAt(undefined, "3", "(parameter) x: number", "");
    try f.VerifyQuickInfoAt(undefined, "4", "(parameter) p: number", "");
    try f.VerifyQuickInfoAt(undefined, "5", "(parameter) q: number", "");
    try f.VerifyQuickInfoAt(undefined, "6", "(parameter) qq: number", "");
    try f.VerifyQuickInfoAt(undefined, "7", "(parameter) p: number", "");
    try f.VerifyQuickInfoAt(undefined, "8", "(parameter) x: number", "");
    try f.VerifyQuickInfoAt(undefined, "9", "(parameter) a: string", "");
    try f.VerifyQuickInfoAt(undefined, "10", "(parameter) b: number", "");
    try f.VerifyQuickInfoAt(undefined, "11", "(parameter) c: boolean", "");
    try f.VerifyQuickInfoAt(undefined, "12", "(parameter) a: string", "");
    try f.VerifyQuickInfoAt(undefined, "13", "(parameter) b: number", "");
    try f.VerifyQuickInfoAt(undefined, "14", "(parameter) c: boolean", "");
}

test "TestMemberListInWithBlock" {
    const content =
        \\class c {
        \\    static x: number;
        \\    public foo() {
        \\        with ({}) {
        \\            function f() { }
        \\            var d = this./*1*/foo;
        \\            /*2*/
        \\        }
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, "1", null);
    // f.VerifyCompletions(undefined, "2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Excludes = &.{
//                 "foo",
//                 "f",
//                 "c",
//                 "d",
//                 "x",
//                 "Object",
//             },
//         },
//     });
}

test "TestImportTypeCompletions8" {
    const content =
        \\// @target: esnext
        \\// @filename: /foo.ts
        \\export interface Foo {}
        \\// @filename: /bar.ts
        \\[|import { type F/**/ }|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/bar.ts");
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =      "Foo",
//                     .InsertText = undefined("import { type Foo } from \"./foo\";"),
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./foo",
//                         },
//                     },
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "Foo",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestTripleSlashRefPathCompletionExtensionsAllowJSTrue" {
    const content =
        \\// @allowJs: true
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
//                 "f1.js",
//                 "f1.jsx",
//                 "f1.ts",
//                 "f1.tsx",
//             },
//         },
//     });
}

test "TestCompletionsImport_previousTokenIsSemicolon" {
    const content =
        \\// @Filename: /a.ts
        \\export function foo() {}
        \\// @Filename: /b.ts
        \\import * as a from 'a';
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
}

test "TestFindAllReferencesFromLinkTagReference1" {
    const content =
        \\enum E {
        \\    /** {@link /**/A} */
        \\    A
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "");
}

test "TestGoToDefinitionYield4" {
    const content =
        \\function* gen() {
        \\    class C { [/*start*/yield 10]() {} }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "start");
}

test "TestImportNameCodeFixNewImportPaths2" {
    const content =
        \\[|foo/*0*/();|]
        \\// @Filename: folder_b/index.ts
        \\export function foo() {};
        \\// @Filename: tsconfig.path.json
        \\{
        \\    "compilerOptions": {
        \\        "baseUrl": ".",
        \\        "paths": {
        \\            "b": [ "folder_b/index" ]
        \\        }
        \\    }
        \\}
        \\// @Filename: tsconfig.json
        \\{
        \\    "extends": "./tsconfig.path",
        \\    "compilerOptions": { }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { foo } from \"b\";\n\nfoo();",
    }, null );
}

test "TestCompletionsImport_default_symbolName" {
    const content =
        \\// @module: commonjs
        \\// @esModuleInterop: false
        \\// @allowSyntheticDefaultImports: false
        \\// @Filename: /node_modules/@types/range-parser/index.d.ts
        \\declare function RangeParser(): string;
        \\declare namespace RangeParser {
        \\    interface Options {
        \\        combine?: boolean;
        \\    }
        \\}
        \\export = RangeParser;
        \\// @Filename: /b.ts
        \\R/*0*/
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
//                     .Label = "RangeParser",
//                     .Kind =  undefined(lsproto.CompletionItemKindFunction),
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "range-parser",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     .Detail =              undefined("namespace RangeParser\nfunction RangeParser(): string"),
//                 },
//             },
//         },
//     });
    // try f.VerifyApplyCodeActionFromCompletion(undefined, undefined("0"), &.{
//         .Name =        "RangeParser",
//         .Source =      "range-parser",
//         .Description = "Add import from \"range-parser\"",
//         .NewFileContent = undefined("import RangeParser = require(\"range-parser\");\n\nR"),
//     });
}

test "TestModuleReexportedIntoGlobalQuickInfo" {
    const content =
        \\// @Filename: /node_modules/@types/three/index.d.ts
        \\export class Vector3 {}
        \\export as namespace THREE;
        \\// @Filename: /global.d.ts
        \\import * as _THREE from 'three';
        \\
        \\declare global {
        \\  const THREE: typeof _THREE;
        \\}
        \\// @Filename: /index.ts
        \\let v = new /*1*/THREE.Vector3();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "const THREE: typeof import(\"three\")", "");
}

test "TestRecursiveClassReference" {
    const content =
        \\declare namespace Thing { }
        \\
        \\namespace Thing {
        \\   var /**/x: Mode;
        \\}
        \\
        \\namespace Thing {
        \\  export class Mode { }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyQuickInfoExists(undefined);
}

test "TestCallHierarchyJsxElement" {
    const content =
        \\// @jsx: preserve
        \\// @filename: main.tsx
        \\function foo() {
        \\    return <Bar/>;
        \\}
        \\
        \\function /**/Bar() {
        \\    baz();
        \\}
        \\
        \\function baz() {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // try f.VerifyBaselineCallHierarchy(undefined);
}

test "TestCodeFixClassImplementInterfacePropertyFromParentConstructorFunction" {
    const content =
        \\class A {
        \\    constructor(public x: number) { }
        \\}
        \\
        \\class B implements A {[| |]}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined);
}

test "TestPathCompletionsPackageJsonImportsIgnoreMatchingNodeModule2" {
    const content =
        \\// @module: node18
        \\// @Filename: /package.json
        \\{
        \\  "imports": {
        \\    "#internal/*": "./src/*.ts"
        \\  }
        \\}
        \\// @Filename: /src/something.ts
        \\export function something(name: string): any;
        \\// @Filename: /src/node_modules/#internal/package.json
        \\{}
        \\// @Filename: /src/a.ts
        \\import {} from "#internal//*1*/";
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
//                 "a",
//                 "something",
//             },
//         },
//     });
}

test "TestFormatBracketInSwitchCase" {
    const content =
        \\// @lib: es5
        \\switch (x) {
        \\    case[]:
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.FormatDocument(undefined, "");
    try f.VerifyCurrentFileContent(undefined, "switch (x) {\n    case []:\n}");
}

test "TestCompletionListInClosedFunction04" {
    const content =
        \\function foo(x: string, y: number, z: boolean) {
        \\    function bar(a: number, b: string = /*1*/, c: typeof x = "hello") {
        \\
        \\    }
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

test "TestImportNameCodeFix_pnpm1" {
    const content =
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{ "compilerOptions": { "module": "commonjs", "types": ["*"], "lib": ["es5"] } }
        \\// @Filename: /home/src/workspaces/project/node_modules/.pnpm/@types+react@17.0.7/node_modules/@types/react/index.d.ts
        \\export declare function Component(): void;
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\Component/**/
        \\// @link: /home/src/workspaces/project/node_modules/.pnpm/@types+react@17.0.7/node_modules/@types/react -> /home/src/workspaces/project/node_modules/@types/react
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { Component } from \"react\";\n\nComponent",
    }, null );
}

test "TestGoToSource3_nodeModulesAtTypes" {
    const content =
        \\// @lib: es5
        \\// @moduleResolution: bundler
        \\// @Filename: /home/src/workspaces/project/node_modules/foo/package.json
        \\{ "name": "foo", "version": "1.0.0", "main": "./lib/main.js" }
        \\// @Filename: /home/src/workspaces/project/node_modules/foo/lib/main.js
        \\export const /*end*/a = "a";
        \\// @Filename: /home/src/workspaces/project/node_modules/@types/foo/package.json
        \\{ "name": "@types/foo", "version": "1.0.0", "types": "./index.d.ts" }
        \\// @Filename: /home/src/workspaces/project/node_modules/@types/foo/index.d.ts
        \\export declare const a: string;
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\import { a } from "foo";
        \\[|a/*start*/|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // try f.VerifyBaselineGoToSourceDefinition(undefined, "start");
}

test "TestCompletionsObjectLiteralWithPartialConstraint" {
    const content =
        \\interface MyOptions {
        \\    hello?: boolean;
        \\    world?: boolean;
        \\}
        \\declare function bar<T extends MyOptions>(options?: Partial<T>): void;
        \\bar({ hello: true, /*1*/ });
        \\
        \\interface Test {
        \\    keyPath?: string;
        \\    autoIncrement?: boolean;
        \\}
        \\
        \\function test<T extends Record<string, Test>>(opt: T) { }
        \\
        \\test({
        \\    a: {
        \\        keyPath: 'x.y',
        \\        autoIncrement: true
        \\    },
        \\    b: {
        \\        /*2*/
        \\    }
        \\});
        \\type Colors = {
        \\    rgb: { r: number, g: number, b: number };
        \\    hsl: { h: number, s: number, l: number }
        \\};
        \\
        \\function createColor<T extends keyof Colors>(kind: T, values: Colors[T]) { }
        \\
        \\createColor('rgb', {
        \\  /*3*/
        \\});
        \\
        \\declare function f<T extends 'a' | 'b', U extends { a?: string }, V extends { b?: string }>(x: T, y: { a: U, b: V }[T]): void;
        \\
        \\f('a', {
        \\  /*4*/
        \\});
        \\
        \\declare function f2<T extends { x?: string }>(x: T): void;
        \\f2({
        \\  /*5*/
        \\});
        \\
        \\type X = { a: { a }, b: { b } }
        \\
        \\function f4<T extends 'a' | 'b'>(p: { kind: T } & X[T]) { }
        \\
        \\f4({
        \\    kind: "a",
        \\    /*6*/
        \\})
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
//                     .Label =      "world?",
//                     .InsertText = undefined("world"),
//                     .FilterText = undefined("world"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
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
//                     .Label =      "autoIncrement?",
//                     .InsertText = undefined("autoIncrement"),
//                     .FilterText = undefined("autoIncrement"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//                 &.{
//                     .Label =      "keyPath?",
//                     .InsertText = undefined("keyPath"),
//                     .FilterText = undefined("keyPath"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
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
//                 "b",
//                 "g",
//                 "r",
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
//                     .Label =      "a?",
//                     .InsertText = undefined("a"),
//                     .FilterText = undefined("a"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
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
//                     .Label =      "x?",
//                     .InsertText = undefined("x"),
//                     .FilterText = undefined("x"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
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
//                 "a",
//             },
//         },
//     });
}

test "TestFormatLiteralTypeInUnionOrIntersectionType" {
    const content =
        \\type NumberAndString = {
        \\    a: number
        \\} & {
        \\    b: string
        \\};
        \\
        \\type NumberOrString = {
        \\    a: number
        \\} | {
        \\    b: string
        \\};
        \\
        \\type Complexed =
        \\    Foo &
        \\    Bar |
        \\    Baz;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    try f.VerifyCurrentFileContent(undefined, "type NumberAndString = {\n    a: number\n} & {\n    b: string\n};\n\ntype NumberOrString = {\n    a: number\n} | {\n    b: string\n};\n\ntype Complexed =\n    Foo &\n    Bar |\n    Baz;");
}

test "TestRenameStringPropertyNames2" {
    const content =
        \\type Props = {
        \\  foo: boolean;
        \\}
        \\
        \\let { foo }: Props = null as any;
        \\foo;
        \\
        \\let asd: Props = { "foo"/**/: true }; // rename foo here
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, null , "");
}

test "TestQuickInfoJSDocFunctionNew" {
    const content =
        \\// @allowJs: true
        \\// @Filename: Foo.js
        \\/** @type {function (new: string, string): string} */
        \\var f/**/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyQuickInfoIs(undefined, "var f: new (arg1: string) => string", "");
}

test "TestJsdocTypedefTagRename02" {
    const content =
        \\// @lib: es5
        \\// @allowNonTsExtensions: true
        \\// @Filename: jsDocTypedef_form2.js
        \\
        \\/** [|@typedef {(string | number)} [|{| "contextRangeIndex": 0 |}NumberLike|]|] */
        \\
        \\/** @type {[|NumberLike|]} */
        \\var numberLike;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // try f.VerifyBaselineRename(undefined, null , ToAny(f.Ranges()[1:]));
}

test "TestCompletionForStringLiteral15" {
    const content =
        \\let x: { [_ in "foo"]: string } = {
        \\    "[|/**/|]"
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
//                     .Label = "foo",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "foo",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestCompletionListInTypeLiteralInTypeParameter3" {
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
        \\var foobar: Bar<{ one: string, /**/
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
//                 "two",
//             },
//         },
//     });
}

test "TestGetOccurrencesAsyncAwait" {
    const content =
        \\[|async|] function f() {
        \\ [|await|] 100;
        \\ [|a/**/wait|] [|await|] 200;
        \\class Foo {
        \\    async memberFunction() {
        \\        await 1;
        \\    }
        \\}
        \\ return [|await|] async function () {
        \\   await 300;
        \\ }
        \\}
        \\async function g() {
        \\    await 300;
        \\    async function f() {
        \\        await 400;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestNavigationBarItemsClass1" {
    const content =
        \\function Foo() {}
        \\class Foo {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestGetOccurrencesIfElse4" {
    const content =
        \\if (true) {
        \\    if (false) {
        \\    }
        \\    else {
        \\    }
        \\    if (true) {
        \\    }
        \\    else {
        \\        /*1*/if (false)
        \\            /*2*/i/*3*/f (true)
        \\                var x = undefined;
        \\    }
        \\}
        \\else            if (null) {
        \\}
        \\else /* whar garbl */ if (undefined) {
        \\}
        \\else
        \\if (false) {
        \\}
        \\else { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Markers()));
}

test "TestSignatureHelpCallExpressionTuples" {
    const content =
        \\function fnTest(str: string, num: number) { }
        \\declare function wrap<A extends any[], R>(fn: (...a: A) => R) : (...a: A) => R;
        \\var fnWrapped = wrap(fnTest);
        \\fnWrapped/*3*/(/*1*/'', /*2*/5);
        \\function fnTestVariadic (str: string, ...num: number[]) { }
        \\var fnVariadicWrapped = wrap(fnTestVariadic);
        \\fnVariadicWrapped/*4*/(/*5*/'', /*6*/5);
        \\function fnNoParams () { }
        \\var fnNoParamsWrapped = wrap(fnNoParams);
        \\fnNoParamsWrapped/*7*/(/*8*/);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "3", "var fnWrapped: (str: string, num: number) => void", "");
    _ = f.GoToMarker(undefined, "1");
    // try f.VerifySignatureHelp(undefined, .{.Text = "fnWrapped(str: string, num: number): void", .ParameterCount = 2, .ParameterName = "str", .ParameterSpan = "str: string"});
    _ = f.GoToMarker(undefined, "2");
    // try f.VerifySignatureHelp(undefined, .{.ParameterName = "num", .ParameterSpan = "num: number"});
    try f.VerifyQuickInfoAt(undefined, "4", "var fnVariadicWrapped: (str: string, ...num: number[]) => void", "");
    _ = f.GoToMarker(undefined, "5");
    // try f.VerifySignatureHelp(undefined, .{.Text = "fnVariadicWrapped(str: string, ...num: number[]): void", .ParameterCount = 2, .ParameterName = "str", .ParameterSpan = "str: string", .IsVariadic = true, .IsVariadicSet = true});
    _ = f.GoToMarker(undefined, "6");
    // try f.VerifySignatureHelp(undefined, .{.ParameterName = "num", .ParameterSpan = "...num: number[]", .IsVariadic = true, .IsVariadicSet = true});
    try f.VerifyQuickInfoAt(undefined, "7", "var fnNoParamsWrapped: () => void", "");
    _ = f.GoToMarker(undefined, "8");
    // try f.VerifySignatureHelp(undefined, .{.Text = "fnNoParamsWrapped(): void", .ParameterCount = 0});
}

test "TestGoToDefinitionUnionTypeProperty_discriminated" {
    const content =
        \\type U = A | B;
        \\
        \\interface A {
        \\  /*aKind*/kind: "a";
        \\  /*aProp*/prop: number;
        \\};
        \\
        \\interface B {
        \\  /*bKind*/kind: "b";
        \\  /*bProp*/prop: string;
        \\}
        \\
        \\const u: U = {
        \\  [|/*kind*/kind|]: "a",
        \\  [|/*prop*/prop|]: 0,
        \\};
        \\const u2: U = {
        \\  [|/*kindBogus*/kind|]: "bogus",
        \\  [|/*propBogus*/prop|]: 0,
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "kind", "prop", "kindBogus", "propBogus");
}

test "TestContextualTypingReturnExpressions" {
    const content =
        \\interface A { }
        \\var f44: (x: A) => (y: A) => A = /*1*/x => /*2*/y => /*3*/x;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "(parameter) x: A", "");
    try f.VerifyQuickInfoAt(undefined, "2", "(parameter) y: A", "");
    try f.VerifyQuickInfoAt(undefined, "3", "(parameter) x: A", "");
}

test "TestQuickInfoSpecialPropertyAssignment" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\class C {
        \\    constructor() {
        \\      /** Doc */
        \\      this./*write*/x = 0;
        \\      this./*read*/x;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "write", "(property) C.x: any", "Doc");
    try f.VerifyQuickInfoAt(undefined, "read", "(property) C.x: number", "Doc");
}

test "TestGoToDefinition_filteringGenericMappedType" {
    const content =
        \\const obj = {
        \\  get /*def*/id() {
        \\    return 1;
        \\  },
        \\  name: "test",
        \\};
        \\
        \\type Omit2<T, DroppedKeys extends PropertyKey> = {
        \\  [K in keyof T as Exclude<K, DroppedKeys>]: T[K];
        \\};
        \\
        \\declare function omit2<O, Mask extends { [K in keyof O]?: true }>(
        \\  obj: O,
        \\  mask: Mask
        \\): Omit2<O, keyof Mask>;
        \\
        \\const obj2 = omit2(obj, {
        \\  name: true,
        \\});
        \\
        \\obj2.[|/*ref*/id|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "ref");
}

test "TestAutoImportPathsNodeModules" {
    const content =
        \\// @Filename: tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "module": "amd",
        \\        "moduleResolution": "node",
        \\        "rootDir": "ts",
        \\        "baseUrl": ".",
        \\        "paths": {
        \\            "*": ["node_modules/@woltlab/wcf/ts/*"]
        \\        }
        \\    },
        \\    "include": [
        \\        "ts",
        \\        "node_modules/@woltlab/wcf/ts",
        \\     ]
        \\}
        \\// @Filename: node_modules/@woltlab/wcf/ts/WoltLabSuite/Core/Component/Dialog.ts
        \\export class Dialog {}
        \\// @Filename: ts/main.ts
        \\Dialog/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"WoltLabSuite/Core/Component/Dialog"}, null );
}

test "TestImportNameCodeFixExistingImport2" {
    const content =
        \\import * as ns from "./module";
        \\// Comment
        \\f1/*0*/();
        \\// @Filename: module.ts
        \\ export function f1() {}
        \\ export var v1 = 5;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import * as ns from \"./module\";\n// Comment\nns.f1();",
        "import * as ns from \"./module\";\nimport { f1 } from \"./module\";\n// Comment\nf1();",
    }, null );
}

test "TestQuickInfoDisplayPartsClassConstructor" {
    const content =
        \\class c {
        \\    /*1*/constructor() {
        \\    }
        \\}
        \\var /*2*/cInstance = new /*3*/c();
        \\var /*4*/cVal = /*5*/c;
        \\class cWithOverloads {
        \\    /*6*/constructor(x: string);
        \\    /*7*/constructor(x: number);
        \\    /*8*/constructor(x: any) {
        \\    }
        \\}
        \\var /*9*/cWithOverloadsInstance = new /*10*/cWithOverloads("hello");
        \\var /*11*/cWithOverloadsInstance2 = new /*12*/cWithOverloads(10);
        \\var /*13*/cWithOverloadsVal = /*14*/cWithOverloads;
        \\class cWithMultipleOverloads {
        \\    /*15*/constructor(x: string);
        \\    /*16*/constructor(x: number);
        \\    /*17*/constructor(x: boolean);
        \\    /*18*/constructor(x: any) {
        \\    }
        \\}
        \\var /*19*/cWithMultipleOverloadsInstance = new /*20*/cWithMultipleOverloads("hello");
        \\var /*21*/cWithMultipleOverloadsInstance2 = new /*22*/cWithMultipleOverloads(10);
        \\var /*23*/cWithMultipleOverloadsInstance3 = new /*24*/cWithMultipleOverloads(true);
        \\var /*25*/cWithMultipleOverloadsVal = /*26*/cWithMultipleOverloads;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestQuickInfoInheritDoc2" {
    const content =
        \\// @noEmit: true
        \\// @allowJs: true
        \\// @Filename: quickInfoInheritDoc2.ts
        \\class Base<T> {
        \\    /**
        \\     * Base.prop
        \\     */
        \\    prop: T | undefined;
        \\}
        \\
        \\class SubClass<T> extends Base<T> {
        \\    /**
        \\     * @inheritdoc
        \\     * SubClass.prop
        \\     */
        \\    /*1*/prop: T | undefined;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestTsxRename5" {
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
        \\    name?: string;
        \\    size?: number;
        \\}
        \\
        \\[|var [|{| "contextRangeIndex": 0 |}nn|]: string;|]
        \\var x = <MyClass name={[|nn|]}></MyClass>;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null , "nn");
}

test "TestBestCommonTypeObjectLiterals" {
    const content =
        \\// @stableTypeOrdering: true
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
    try f.VerifyQuickInfoAt(undefined, "1", "var c: {\n    name: string;\n    age: number;\n}[]", "");
    try f.VerifyQuickInfoAt(undefined, "2", "var c1: {\n    name: string;\n    age: number;\n}[]", "");
    try f.VerifyQuickInfoAt(undefined, "3", "var c2: ({\n    name: string;\n    age: number;\n    address: string;\n} | {\n    name: string;\n    age: number;\n    dob: Date;\n})[]", "");
    try f.VerifyQuickInfoAt(undefined, "4", "var c3: I[]", "");
}

test "TestFormattingOnEmptyInterfaceLiteral" {
    const content =
        \\/*1*/    function    foo  (  x  :    {    }    )    {    }
        \\
        \\/*2*/foo    (  {     }   )    ;
        \\
        \\
        \\
        \\/*3*/            interface    bar    {
        \\/*4*/                x   :    {     }   ;
        \\/*5*/       y  :       (         )    =>    {     }   ;
        \\/*6*/                                                    }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCurrentLineContent(undefined, "function foo(x: {}) { }");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyCurrentLineContent(undefined, "foo({});");
    _ = f.GoToMarker(undefined, "3");
    try f.VerifyCurrentLineContent(undefined, "interface bar {");
    _ = f.GoToMarker(undefined, "4");
    try f.VerifyCurrentLineContent(undefined, "    x: {};");
    _ = f.GoToMarker(undefined, "5");
    try f.VerifyCurrentLineContent(undefined, "    y: () => {};");
    _ = f.GoToMarker(undefined, "6");
    try f.VerifyCurrentLineContent(undefined, "}");
}

test "TestCodeFixImplicitThis_ts_cantFixNonFunction" {
    const content =
        \\// @noImplicitThis: true
        \\this;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined);
}

test "TestJsQuickInfoGenerallyAcceptableSize" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: index.js
        \\// Data table
        \\/**
        \\    @typedef DataTableThing
        \\    @type {Object}
        \\    @property {function(TagCollection, Location, string, string, Infotable):void} AddDataTableEntries - (arg0: tags, arg1: location, arg2: source, arg3: sourceType, arg4: values) Add multiple data table entries.
        \\    @property {function(TagCollection, Location, string, string, Infotable):string} AddDataTableEntry - (arg0: tags, arg1: location, arg2: source, arg3: sourceType, arg4: values) Add a new data table entry.
        \\    @property {function(TagCollection, Location, string, string, Infotable):void} AddOrUpdateDataTableEntries - (arg0: tags, arg1: location, arg2: source, arg3: sourceType, arg4: values) Add or update multiple data table entries.
        \\    @property {function(TagCollection, Location, string, string, Infotable):string} AddOrUpdateDataTableEntry - (arg0: tags, arg1: location, arg2: source, arg3: sourceType, arg4: values)  Add a new data table entry, or if it exists, update an existing entry.
        \\    @property {function(TagCollection, Location, string, string, Infotable):void} AssignDataTableEntries - (arg0: tags, arg1: location, arg2: source, arg3: sourceType, arg4: values) Replaces existing data table entries.
        \\    @property {function():Infotable} CreateValues - Create an empty info table of the correct datashape for this data table.
        \\    @property {function(*):Infotable} CreateValuesWithData - (arg0: values as JSONObject) Create an info table of the correct datashape for this stream and include data values.
        \\    @property {function(Infotable):void} DeleteDataTableEntries - (arg0: values as Infotable) Delete all table entries that match the provided values.
        \\    @property {function(TagCollection, Location, string, string, Infotable, *):void} DeleteDataTableEntriesWithQuery - (arg0: tags, arg1: location, arg2: source, arg3: sourceType, arg4: values, arg5: query as JSONObject) Delete multiple data table entries based on a query.
        \\    @property {function(Infotable):void} DeleteDataTableEntry - (arg0: values as Infotable) Delete an existing data table entry
        \\    @property {function(string):void} DeleteDataTableEntryByKey - (arg0: key) Delete an existing data table entry using its key value.
        \\    @property {function(Infotable):Infotable} FindDataTableEntries - (arg0: values as Infotable) Retrieve all table entries that match the provided values.
        \\    @property {function():DataShapeDefinition} getDataShape
        \\    @property {function():string} GetDataShape - Get the currently assigned data shape.
        \\    @property {function():string} getDataShapeName
        \\    @property {function(number):Infotable} GetDataTableEntries - (arg0: maxItems) Retrieve all table entries up to max items number.
        \\    @property {function(Infotable):Infotable} GetDataTableEntry - (arg0: values as Infotable) Get an existing data table entry.
        \\    @property {function(string):Infotable} GetDataTableEntryByKey - (arg0: key) Get an existing data table entry using its key value.
        \\    @property {function():number} GetDataTableEntryCount - Get an count of data table entries.
        \\    @property {function():ThingworxRelationshipTypes} getDataType
        \\    @property {function():EntityReferenceTypeMap} getDependencies
        \\    @property {function():IDataEntryCloseableIterator} getEntryIterator - Returns an iterator over all entries inside this data table thing.
        \\    @property {function():Infotable} GetFieldNames - Retrieve a list of field names for the data shape associated with this stream.
        \\    @property {function(string):Infotable} GetFieldNamesByType - (arg0: key) Retrieve a list of field names for the data shape associated with this stream, of a specific type.
        \\    @property {function():string} getItemCollectionName
        \\    @property {function():string} getItemEntityName
        \\    @property {function():ThingworxRelationshipTypes} getItemEntityType
        \\    @property {function():void} initializeEntity
        \\    @property {function():void} initializeThing
        \\    @property {function():boolean}    isStoredAsEncrypted
        \\    @property {function():void} PurgeDataTableEntries - Remove all data table entries.
        \\    @property {function(Infotable, number, TagCollection, string, *):Infotable} QueryDataTableEntries - (arg0: values, arg1: maxItems, arg2: tags, arg3: source, arg4: query as JSONObject) Retrieve all table entries that match the query parameters.
        \\    @property {function():void} Reindex - Reindex the custom indexes on the data table.
        \\    @property {function(number, string, TagCollection, *, string):Infotable} SearchDataTableEntries - (arg0: maxItems, arg1: searchExpression, arg2: tags, arg3: query as JSONObject, arg4: source)  Retrieve all table entries that match the search query parameters.
        \\    @property {function(string):void} SetDataShape - (arg0: name) Sets the data shape.
        \\    @property {function(TagCollection, Location, string, string, Infotable):void} UpdateDataTableEntries - (arg0: tags, arg1: location, arg2: source, arg3: sourceType, arg4: values) Update multiple data table entries.
        \\    @property {function(TagCollection, Location, string, string, Infotable, *, Infotable):void} UpdateDataTableEntriesWithQuery - (arg0: tags, arg1: location, arg2: source, arg3: sourceType, arg4: values, arg5: query as JSONObject, arg6: updatValues) Add or update multiple data table entries based on a query.
        \\    @property {function(TagCollection, Location, string, string, Infotable):void} UpdateDataTableEntry - (arg0: tags, arg1: location, arg2: source, arg3: sourceType, arg4: values) update an existing data table entry.
        \\    @property {function(ImportedEntityCollection):void} validateConfiguration - (arg0: importedEntityCollections)
        \\*/
        \\
        \\/**
        \\    @typedef Infotable
        \\    @type {object}
        \\    @property {boolean} isCompressed
        \\    @property {DataShape} dataShape
        \\    @property {function(FieldDefinition):int} addField - Adds a field to the DataShapeDefinition of this InfoTable, given a FieldDefinition
        \\    @property {function(*):void} AddField - *FROM SNIPPET* adds a new field definition to the datashape (arg0 is an object that should match with datashape)
        \\    @property {function(object):void} AddRow - *FROM SNIPPET* adds a row to the infotable (arg0 is an object that should match with datashape)
        \\    @property {function(ValueCollection):int} addRow - Adds a row to this InfoTable's ValueCollectionList given a ValueCollection
        \\    @property {ValueCollectionList} rows - returns the ValueCollectionList of the rows in this InfoTable
        \\    @property {function(Infotable, boolean):int} addRowsFrom - Adds the rows from an InfoTable to this InfoTable given: the InfoTable to be copied from and a Boolean indicating whether the copied values should be references or cloned values. (arg 0: infotable, arg1: clone)
        \\    @property {function():Infotable} clone
        \\    @property {function():Infotable} cloneStructure
        \\    @property {function():ValueCollection} currentRow - Returns the current row in this InfoTable as a ValueCollection
        \\    @property {function(object):void} Delete - *FROM SNIPPET* delete rows by value filter (arg0 is an object that should match with datashape)
        \\    @property {function(IFilter):int} delete
        \\    @property {function(ValueCollection):int} delete - Creates an AndFilterCollection based on the given ValueCollection and deletes all rows falling within the parameters of that filter
        \\    @property {function(IFilter):Infotable} deleteRowsToNewTable
        \\    @property {function(object):void} Filter - *FROM SNIPPET* filters the infotable (arg0 is an object that should match with datashape)
        \\    @property {function(ValueCollection):void} filter - Creates an AndFilterCollection based on the given ValueCollection and applies it to this InfoTable
        \\    @property {function(IFilter):void} filterRows
        \\    @property {function(IFilter):Infotable} filterRowsToNewTable
        \\    @property {function(*):Infotable} FilterToNewTable - Finds rows in this InfoTable with values that match the values given as a JSONObject and returns them as a new InfoTable
        \\    @property {function(object):void} Find - *FROM SNIPPET* retrieve rows by value filter (arg0 is an object that should match with datashape)
        \\    @property {function(IFilter):ValueCollection} find - Finds and returns a row from this InfoTable that falls within the parameters of the given IFilter
        \\    @property {function(ValueCollection):ValueCollection} find - Finds and returns a row from this InfoTable that matches the values of all fields given as a (ValueCollection)
        \\    @property {function(ValueCollection, string[]):ValueCollection} find - Finds and returns a row in this InfoTable given the fields to search as a String Array and the values to match as a ( ValueCollection)
        \\    @property {function(ValueCollection):int} findIndex - Finds and returns the index of a row from this InfoTable that matches the values of all fields given as a ( ValueCollection)
        \\    @property {function(*):Infotable} fromJSON
        \\    @property {function():DataShapeDefinition} getDataShape - Returns the DataShapeDefinition for this InfoTable
        \\    @property {function(string):FieldDefinition} getField - Returns a FieldDefinition from this InfoTable's DataShapeDefinition, given the name of the field as a String
        \\    @property {function():int} getFieldCount - Returns the number of fields in this InfoTable's DataShape as an int
        \\    @property {function():ValueCollection} getFirstRow - Returns the first row (ValueCollection) of this InfoTable
        \\    @property {function():InfoTableRowIndex} getIndex -
        \\    @property {function():ValueCollection} getLastRow - Returns the last row in this InfoTable as a ValueCollection
        \\    @property {function():number} getLength - Returns the number of rows in this InfoTable as an Integer
        \\    @property {function():DataShapeDefinition} getPublicDataShape - Returns a DataShapeDefinition for this InfoTable containing only the public fields
        \\    @property {function():*} getReturnValue - Returns the first value of the first field in the first row of this InfoTable
        \\    @property {function(number):ValueCollection} getRow - *FROM SNIPPET* retrieves a row by index
        \\    @property {function():number} getRowCount - *FROM SNIPPET* gets the count of rows
        \\    @property {function():ValueCollectionList} getRows - Returns a ValueCollectionList of the rows in this InfoTable
        \\    @property {function(string):IPrimitiveType} getRowValue - Returns a value as an IPrimitiveType from the first row of this InfoTable, given a field name as a String
        \\    @property {function(string):boolean} hasField - Verifies a field exists in this InfoTable's DataShape given the field name as a String
        \\    @property {function(string[],boolean):void} indexOn
        \\    @property {function(string, boolean):void} indexOn
        \\    @property {function():boolean} isEmpty - Returns a boolean indicating whether this InfoTable has a size of zero
        \\    @property {function(BaseTypes):boolean} isType
        \\    @property {function():void} moveToFirst - Moves to the first row of this InfoTable.
        \\    @property {function():ValueCollection} nextRow - Returns the row after the current row in this InfoTable as a ValueCollection
        \\    @property {function(string):void} quickSort - (arg0: fieldName)
        \\    @property {function(string, boolean):void} quickSort - (arg0: fieldName, arg1: isAscending)
        \\    @property {function():void} RemoveAllRows - *FROM SNIPPET* remove all rows from infotable
        \\    @property {function():void} removeAllRows - remove all rows from infotable
        \\    @property {function(string):void} RemoveField - *FROM SNIPPET* remove a datashape field by name
        \\    @property {function(number):void} RemoveRow - *FROM SNIPPET* removes a row by index
        \\    @property {function(number):void} removeRow - Removes a ValueCollection from the InfoTable given the row as an int
        \\    @property {function(DataShapeDefinition):void} setDataShape - Sets DataShapeDefinition for this InfoTable
        \\    @property {function():void} setRow - Sets a single row in this InfoTable given a ValueCollection as a row and the index of the row to be replaced
        \\    @property {function(ValueCollectionList):void} setRows - Sets the rows in this InfoTable given a ValueCollectionList
        \\    @property {function(Sort):void} Sort - *FROM SNIPPET* sorts the table
        \\    @property {function(ISort):void} sortRows
        \\    @property {function():Infotable} sortRowsToNewTable
        \\    @property {function():*} toJSON
        \\    @property {function():JsonInfotable} ToJSON - *FROM SNIPPET* returns the table as JsonInfotable
        \\    @property {function(number):void} topN - (arg0: maxItems)
        \\    @property {function(number):Infotable} topNToNewTable - (arg0: maxItems)
        \\    @property {function(IFIlter, ValueCollection):Infotable} updateRowsToNewTable - (arg0: filters, arg1: values)
        \\*/
        \\
        \\/**
        \\    @typedef DataShapeDefinition
        \\    @type {object}
        \\    @property {function(FieldDefinition):void} addFieldDefinition - Adds a new field definition to this data shape definition.
        \\    @property {function():DataShapeDefinition} clone - Creates a deep clone of this data shape definition
        \\    @property {function():FieldDefinition} getFieldDefinition - Returns the field definition with the specified name.
        \\    @property {function():FieldDefinitionCollection} getFields - Returns the collection of field definitions belonging to this data shape definition.
        \\    @property {function():boolean} hasField - Tests if the field named exists in this definition.
        \\    @property {function():boolean} hasPrimaryKey - Tests if this definition contains any fields that are designated as primary keys.
        \\    @property {function():boolean} matches - Determines if this data shape definition has the same fields with the same base types as the provided data shape definition.
        \\    @property {function():void} setFields - Replaces the fields belonging to this data shape definition with the fields provided in the specified collection.
        \\    @property {function():*} toJSON - Serializes this data shape definition into JSON format.
        \\*/
        \\
        \\/**
        \\    @typedef FieldDefinition
        \\    @type {object}
        \\    @property {function(AspectCollection):boolean} aspectsMatch - Determines whether or not the aspects assigned to this field are equivalent to the aspects in the provided collection.
        \\    @property {function():FieldDefinition} clone - Creates a deep clone of this field definition.
        \\    @property {function():AspectCollection} getAspects - Returns the collection of aspects belonging to this field.
        \\    @property {function():BaseTypes} getBaseType - Returns the base type assigned to this field.
        \\    @property {function():string} getDataShapeName - Returns the data shape name assigned to the ASPECT_DATASHAPE aspect, if the base type for this field is set to INFOTABLE.
        \\    @property {function():IPrimitiveType} getDefaultValue - Returns the default value assigned to this field, if one has been defined according to the ASPECT_DEFAULTVALUE aspect.
        \\    @property {function():number} getOrdinal - Returns the ordinal value assigned to this field.
        \\    @property {function():boolean} hasDataShape - Determines if, when the base type of this field is an INFOTABLE, a data shape has been assigned.
        \\    @property {function():boolean} hasDefaultValue - Determines if this field has a default value according to the ASPECT_DEFAULTVALUE aspect.
        \\    @property {function():boolean} isDataTableEntry - Determines if, when the base type of this field is an INFOTABLE, the contents of the info table will be derived from a data table entry.
        \\    @property {function():boolean} isPrimaryKey - Determines if this field has the ASPECT_ISPRIMARYKEY aspect set to true.
        \\    @property {function():boolean} isPrivate - Determines if this field has the ASPECT_ISPRIVATE aspect set to true.
        \\    @property {function():boolean} isRequired - Determines if this field has the ASPECT_ISREQUIRED aspect set to true.
        \\    @property {function():boolean} isStreamEntry - Determines if, when the base type of this field is an INFOTABLE, the contents of the info table will be derived from a stream entry.
        \\    @property {function(AspectCollection):void} setAspects - Replaces all aspects on this field with the aspects in the specified collection.
        \\    @property {function(BaseTypes):void} setBaseType - Assigns the specified base type to this field.
        \\    @property {function(number):void} setOrdinal - Sets the ordinal value for this field.
        \\*/
        \\
        \\/**
        \\    @typedef ValueCollectionList
        \\    @type {ArrayList}
        \\    @property {function():Infotable} convertToTypedInfoTable
        \\    @property {function():ValueCollection} currentRow
        \\    @property {function(ValueCollection):ValueCollection} find - arg0: values
        \\    @property {function(ValueCollection, string[]):ValueCollection} find - arg0: values, arg1: columns
        \\    @property {function(ValueCollection):number} findIndex
        \\    @property {function():ValueCollection} getFirstRow
        \\    @property {function():ValueCollection} getLastRow
        \\    @property {function():number} getLength
        \\    @property {function(number):ValueCollection} getRow - arg0: index
        \\    @property {function():number} getRowCount
        \\    @property {function(string):IPrimitiveType} getRowValue - arg0: name
        \\    @property {function():void} moveToFirst
        \\    @property {function():ValueCollection} nextRow
        \\*/
        \\
        \\/**
        \\    @typedef ValueCollection
        \\    @type {NamedObject}
        \\    @property {function():ValueCollection} clone
        \\    @property {function(*,DataShapeDefinition):ValueCollection} fromJSONTyped
        \\    @property {function(string):*}     getJSONSerializedValue
        \\    @property {function(string):IPrimitiveType}  getPrimitive
        \\    @property {function(string):string}  getStringValue
        \\    @property {function(string):*} getValue
        \\    @property {function(string):boolean} has
        \\    @property {function(ValueCollection):boolean} matches
        \\    @property {function():Infotable} toInfoTable
        \\    @property {function():*} toJSON
        \\    @property {function(DataShapeDefinition):*} toJSONTyped
        \\    @property {function():NamedValueCollection} toNamedValueCollection
        \\*/
        \\
        \\
        \\/**
        \\ * Do something
        \\ * @param {DataTableThing} dataTable
        \\ */
        \\var doSome/*1*/thing = function (dataTable) {
        \\};
        \\
        \\/**
        \\ * @callback SomeCallback
        \\ * @param {number} foo
        \\ * @param {string} bar
        \\ */
        \\
        \\ /**
        \\  * Another thing
        \\  * @type {SomeCallback}
        \\  */
        \\var anotherThing/*2*/ = function(a, b) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "var doSomething: (dataTable: DataTableThing) => void", "Do something");
    try f.VerifyQuickInfoAt(undefined, "2", "var anotherThing: SomeCallback", "Another thing");
}

test "TestOrganizeImports18" {
    const content =
        \\// @filename: /A.ts
        \\export interface A {}
        \\export function bFuncA(a: A) {}
        \\// @filename: /B.ts
        \\export interface B {}
        \\export function bFuncB(b: B) {}
        \\// @filename: /C.ts
        \\export interface C {}
        \\export function bFuncC(c: C) {}
        \\// @filename: /test.ts
        \\export { C } from "./C";
        \\export { B } from "./B";
        \\export { A } from "./A";
        \\
        \\export { bFuncC } from "./C";
        \\export { bFuncB } from "./B";
        \\export { bFuncA } from "./A";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/test.ts");
    // try f.VerifyOrganizeImports(undefined,
//         "export { A } from \"./A\";\nexport { B } from \"./B\";\nexport { C } from \"./C\";\n\nexport { bFuncA } from \"./A\";\nexport { bFuncB } from \"./B\";\nexport { bFuncC } from \"./C\";\n",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
}

test "TestUnusedImports1FS" {
    const content =
        \\// @noUnusedLocals: true
        \\// @Filename: file2.ts
        \\  [|import { Calculator } from "./file1" |]
        \\// @Filename: file1.ts
        \\   export class Calculator {
        \\
        \\   }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyRangeAfterCodeFix(undefined, "", false, 0, 0);
}

test "TestGoToDefinitionAlias" {
    const content =
        \\// @Filename: b.ts
        \\import /*alias1Definition*/alias1 = require("fileb");
        \\namespace Module {
        \\    export import /*alias2Definition*/alias2 = alias1;
        \\}
        \\
        \\// Type position
        \\var t1: [|/*alias1Type*/alias1|].IFoo;
        \\var t2: Module.[|/*alias2Type*/alias2|].IFoo;
        \\
        \\// Value posistion
        \\var v1 = new [|/*alias1Value*/alias1|].Foo();
        \\var v2 = new Module.[|/*alias2Value*/alias2|].Foo();
        \\// @Filename: a.ts
        \\export class Foo {
        \\    private f;
        \\}
        \\export interface IFoo {
        \\    x;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "alias1Type", "alias1Value", "alias2Type", "alias2Value");
}

test "TestCompletionsDefaultKeywordWhenDefaultExportAvailable" {
    const content =
        \\// @filename: index.ts
        \\export default function () {}
        \\def/*1*/
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
//                     .Label =    "default",
//                     .Kind =     undefined(lsproto.CompletionItemKindKeyword),
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestInlayHintsInteractiveWithClosures" {
    const content =
        \\function foo1(a: number) {
        \\    return (b: number) => {
        \\        return a + b
        \\    }
        \\}
        \\foo1(1)(2);
        \\function foo2(a: (b: number) => number) {
        \\    return a(1) + 2
        \\}
        \\foo2((c: number) => c + 1);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayParameterNameHints = lsutil.IncludeInlayParameterNameHintsAll}});
}

test "TestGetEditsForFileRename_symlink" {
    const content =
        \\// @Filename: /foo.ts
        \\// @Symlink: /node_modules/foo/index.ts
        \\export const x = 0;
        \\// @Filename: /user.ts
        \\import { x } from 'foo';
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyNoErrors(undefined);
    try f.VerifyWillRenameFilesEdits(undefined, "/user.ts", "/luser.ts", .{}, null );
}

test "TestInlayHintsFunctionParameterTypes2" {
    const content =
        \\class C {}
        \\namespace N { export class Foo {} }
        \\interface Foo {}
        \\function f1(a = 1) {}
        \\function f2(a = "a") {}
        \\function f3(a = true) {}
        \\function f4(a = { } as Foo) {}
        \\function f5(a = <Foo>{}) {}
        \\function f6(a = {} as const) {}
        \\function f7(a = (({} as const))) {}
        \\function f8(a = new C()) {}
        \\function f9(a = new N.C()) {}
        \\function f10(a = ((((new C()))))) {}
        \\function f11(a = { a: 1, b: 1 }) {}
        \\function f12(a = ((({ a: 1, b: 1 })))) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayFunctionParameterTypeHints = core.TSTrue}});
}

test "TestModuleEnumModule" {
    const content =
        \\namespace A {
        \\    var o;
        \\}
        \\enum A {
        \\    /**/c
        \\}
        \\namespace A {
        \\    var p;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyQuickInfoExists(undefined);
}

test "TestSignatureHelpSimpleConstructorCall" {
    const content =
        \\class ConstructorCall {
        \\    constructor(str: string, num: number) {
        \\    }
        \\}
        \\var x = new ConstructorCall(/*constructorCall1*/1,/*constructorCall2*/2);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "constructorCall1");
    // try f.VerifySignatureHelp(undefined, .{.Text = "ConstructorCall(str: string, num: number): ConstructorCall", .ParameterName = "str", .ParameterSpan = "str: string"});
    _ = f.GoToMarker(undefined, "constructorCall2");
    // try f.VerifySignatureHelp(undefined, .{.Text = "ConstructorCall(str: string, num: number): ConstructorCall", .ParameterName = "num", .ParameterSpan = "num: number"});
}

test "TestSyntacticClassificationsJsx2" {
    const content =
        \\// @Filename: file1.tsx
        \\let x  = <div.name b = "some-value" c = {1}>
        \\    some jsx text
        \\</div.name>;
        \\
        \\let y = <element.name attr="123"/>
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "variable.declaration", .Text = "x"},
//         .{.Type = "variable.declaration", .Text = "y"},
//     });
}

test "TestCompletionForStringLiteralInIndexedAccess01" {
    const content =
        \\interface Foo {
        \\    foo: string;
        \\    bar: string;
        \\}
        \\
        \\let x: Foo["[|/*1*/|]"]
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
//             },
//         },
//     });
}

test "TestGetOutliningSpansForRegions" {
    const content =
        \\// @lib: es5
        \\// region without label
        \\[|// #region
        \\
        \\// #endregion|]
        \\
        \\// region without label with trailing spaces
        \\[|// #region
        \\
        \\// #endregion|]
        \\
        \\// region with label
        \\[|// #region label1
        \\
        \\// #endregion|]
        \\
        \\// region with extra whitespace in all valid locations
        \\             [|//              #region          label2    label3
        \\
        \\        //        #endregion|]
        \\
        \\// No space before directive
        \\[|//#region label4
        \\
        \\//#endregion|]
        \\
        \\// Nested regions
        \\[|// #region outer
        \\
        \\[|// #region inner
        \\
        \\// #endregion inner|]
        \\
        \\// #endregion outer|]
        \\
        \\// region delimiters not valid when there is preceding text on line
        \\ test // #region invalid1
        \\
        \\test // #endregion
        \\
        \\// region delimiters not valid when in multiline comment
        \\/*
        \\// #region invalid2
        \\*/
        \\
        \\/*
        \\// #endregion
        \\*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // try f.VerifyOutliningSpans(undefined, lsproto.FoldingRangeKindRegion);
}

test "TestCompletionsDotDotDotInObjectLiteral1" {
    const content =
        \\// https://github.com/microsoft/TypeScript/issues/57540
        \\
        \\const foo = { b: 100 };
        \\
        \\const bar: {
        \\  a: number;
        \\  b: number;
        \\} = {
        \\  a: 42,
        \\  .../*1*/
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
//             .Includes = &.{
//                 "foo",
//             },
//             .Excludes = &.{
//                 "b",
//             },
//         },
//     });
}

test "TestGoToDefinitionOverriddenMember21" {
    const content =
        \\// @strict: true
        \\// @target: esnext
        \\// @lib: esnext
        \\const prop = "foo" as const;
        \\
        \\abstract class A {}
        \\
        \\export class B extends A {
        \\  static [|/*1*/override|] readonly [prop] = "B";
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestJsDocFunctionSignatures5" {
    const content =
        \\// @strict: true
        \\// @allowJs: true
        \\// @Filename: Foo.js
        \\/**
        \\ * Filters a path based on a regexp or glob pattern.
        \\ * @param {String} basePath The base path where the search will be performed.
        \\ * @param {String} pattern A string defining a regexp of a glob pattern.
        \\ * @param {String} type The search pattern type, can be a regexp or a glob.
        \\ * @param {Object} options A object containing options to the search.
        \\ * @return {Array} A list containing the filtered paths.
        \\ */
        \\function pathFilter(basePath, pattern, type, options){
        \\//...
        \\}
        \\pathFilter(/**/'foo', 'bar', 'baz', {});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSignatureHelp(undefined);
}

test "TestGetOccurrencesDeclare1" {
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
        \\    export [|declare|] namespace ma.m1.m2.m3 {
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
        \\            }
        \\        }
        \\    }
        \\
        \\    [|declare|] var ambientThing: number;
        \\    export var exportedThing = 10;
        \\    [|declare|] function foo(): string;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestSignatureHelpConstructExpression" {
    const content =
        \\class sampleCls { constructor(str: string, num: number) { } }
        \\var x = new sampleCls(/*1*/"", /*2*/5);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // try f.VerifySignatureHelp(undefined, .{.Text = "sampleCls(str: string, num: number): sampleCls", .ParameterCount = 2, .ParameterName = "str", .ParameterSpan = "str: string"});
    _ = f.GoToMarker(undefined, "2");
    // try f.VerifySignatureHelp(undefined, .{.ParameterName = "num", .ParameterSpan = "num: number"});
}

test "TestFormatWithStatement" {
    const content =
        \\with /*1*/(foo.bar)
        \\
        \\   {/*2*/
        \\
        \\     }/*3*/
        \\
        \\with (bar.blah)/*4*/
        \\{/*5*/
        \\}/*6*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.GetOptions();
    // f.Configure(undefined, opts227);
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCurrentLineContent(undefined, "with (foo.bar) {");
    _ = f.GoToMarker(undefined, "3");
    try f.VerifyCurrentLineContent(undefined, "}");
    _ = f.GoToMarker(undefined, "4");
    try f.VerifyCurrentLineContent(undefined, "with (bar.blah) {");
    _ = f.GoToMarker(undefined, "6");
    try f.VerifyCurrentLineContent(undefined, "}");
    // f.GetOptions();
    // f.Configure(undefined, opts565);
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCurrentLineContent(undefined, "with (foo.bar)");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyCurrentLineContent(undefined, "{");
    _ = f.GoToMarker(undefined, "4");
    try f.VerifyCurrentLineContent(undefined, "with (bar.blah)");
    _ = f.GoToMarker(undefined, "5");
    try f.VerifyCurrentLineContent(undefined, "{");
}

test "TestGoToImplementationSuper_01" {
    const content =
        \\class [|Foo|] {
        \\    hello() {}
        \\}
        \\
        \\class Bar extends Foo {
        \\    hello() {
        \\        sup/*super_call*/er.hello();
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "super_call");
}

test "TestDocCommentTemplateRegex" {
    const content =
        \\var regex = /*0*///*1*/asdf/*2*/ /*3*///*4*/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.Markers();
    // try f.VerifyNoJSDocCompletion(undefined, marker);
}

test "TestLambdaThisMembers" {
    const content =
        \\class Foo {
        \\    a: number;
        \\    b() {
        \\        var x = () => {
        \\            this./**/;
        \\        }
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
//             .Exact = &.{
//                 "a",
//                 "b",
//             },
//         },
//     });
}

test "TestCodeFixOverrideModifier18" {
    const content =
        \\// @noImplicitOverride: true
        \\class A {
        \\    static foo() {}
        \\}
        \\class B extends A {
        \\    [|static foo() {}|]
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined, "fixAddOverrideModifier");
}

test "TestCompletionsImport_exportEquals_global" {
    const content =
        \\// @lib: es5
        \\// @module: es6
        \\// @Filename: /console.d.ts
        \\ interface Console {}
        \\ declare var console: Console;
        \\ declare module "console" {
        \\   export = console;
        \\ }
        \\// @Filename: /react-native.d.ts
        \\ import 'console';
        \\ declare global {
        \\   interface Console {}
        \\   var console: Console;
        \\ }
        \\// @Filename: /a.ts
        \\conso/**/
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
//                         .Label =               "console",
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                         .SortText =            undefined(string(ls.SortTextGlobalsOrKeywords)),
//                     },
//                 }, false,
//             ),
//         },
//     });
}

test "TestSignatureHelpWithInvalidArgumentList1" {
    const content =
        \\function foo(a) { }
        \\foo(hello my name /**/is
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // try f.VerifySignatureHelp(undefined, .{.Text = "foo(a: any): void"});
}

test "TestClosedCommentsInConstructor" {
    const content =
        \\class Foo {
        \\    constructor(/* /**/ */) { }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, "", null);
}

test "TestQuickInfoDisplayPartsModules" {
    const content =
        \\namespace /*1*/m {
        \\    var /*2*/namespaceElemWithoutExport = 10;
        \\    export var /*3*/namespaceElemWithExport = 10;
        \\}
        \\var /*4*/a = /*5*/m;
        \\var /*6*/b: typeof /*7*/m;
        \\namespace /*8*/m1./*9*/m2 {
        \\    var /*10*/namespaceElemWithoutExport = 10;
        \\    export var /*11*/namespaceElemWithExport = 10;
        \\}
        \\var /*12*/x = /*13*/m1./*14*/m2;
        \\var /*15*/y: typeof /*16*/m1./*17*/m2;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestRenameImportSpecifierPropertyName" {
    const content =
        \\// @Filename: canada.ts
        \\export interface /**/Ginger {}
        \\// @Filename: dry.ts
        \\import { Ginger as Ale } from './canada';
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, null , "");
}

test "TestAutoImportFileExcludePatterns2" {
    const content =
        \\// @lib: es5
        \\// @Filename: /lib/components/button/Button.ts
        \\export function Button() {}
        \\// @Filename: /lib/components/button/index.ts
        \\export * from "./Button";
        \\// @Filename: /lib/components/index.ts
        \\export * from "./button";
        \\// @Filename: /lib/main.ts
        \\export { Button } from "./components";
        \\// @Filename: /lib/index.ts
        \\export * from "./main";
        \\// @Filename: /i-hate-index-files.ts
        \\Button/**/
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
//                         .Label = "Button",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "./lib/main",
//                             },
//                         },
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     },
//                 }, false,
//             ),
//         },
//         .UserPreferences = &.{.AutoImportFileExcludePatterns = &.{"/**/index.*"}},
//     });
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"./lib/main", "./lib/components/button/Button"}, &.{.AutoImportFileExcludePatterns = &.{"/**/index.*"}});
}

test "TestCompletionListBeforeNewScope01" {
    const content =
        \\p/*1*/
        \\
        \\function fun(param) {
        \\    let party = Math.random() < 0.99;
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
//             .Excludes = &.{
//                 "param",
//                 "party",
//             },
//         },
//     });
}

test "TestCodeFixClassImplementClassMethodViaHeritage" {
    const content =
        \\class C1 {
        \\    f1() {}
        \\}
        \\
        \\class C2 extends C1 {
        \\
        \\}
        \\
        \\class C3 implements C2 {[| 
        \\    |]f2(){}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyRangeAfterCodeFix(undefined, "f1(): void{\n    throw new Error(\"Method not implemented.\");\n}\n", false, 0, 0);
}

test "TestAutoImportTypeImport4" {
    const content =
        \\// @verbatimModuleSyntax: true
        \\// @target: esnext
        \\// @Filename: /exports1.ts
        \\export const a = 0;
        \\export const A = 1;
        \\export const b = 2;
        \\export const B = 3;
        \\export const c = 4;
        \\export const C = 5;
        \\export type x = 6;
        \\export const X = 7;
        \\export const Y = 8;
        \\export const Z = 9;
        \\// @Filename: /exports2.ts
        \\export const d = 0;
        \\export const D = 1;
        \\export const e = 2;
        \\export const E = 3;
        \\// @Filename: /index0.ts
        \\import { A, B, C } from "./exports1";
        \\a/*0*//*0a*/;
        \\b;
        \\// @Filename: /index1.ts
        \\import { A, B, C, type Y, type Z } from "./exports1";
        \\a/*1*//*1a*//*1b*//*1c*/;
        \\b;
        \\// @Filename: /index2.ts
        \\import { A, a, B, b, type Y, type Z } from "./exports1";
        \\import { E } from "./exports2";
        \\d/*2*//*2a*//*2b*//*2c*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "0");
    // try f.VerifyImportFixAtPosition(undefined, &.{
//         "import { a, A, B, C } from \"./exports1\";\na;\nb;",
//         "import { A, b, B, C } from \"./exports1\";\na;\nb;",
//     }, &.{.OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderLast});
    _ = f.GoToMarker(undefined, "0a");
    // try f.VerifyImportFixAtPosition(undefined, &.{
//         "import { a, A, B, C } from \"./exports1\";\na;\nb;",
//         "import { A, b, B, C } from \"./exports1\";\na;\nb;",
//     }, &.{.OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderLast});
    _ = f.GoToMarker(undefined, "1");
    // try f.VerifyImportFixAtPosition(undefined, &.{
//         "import { a, A, B, C, type Y, type Z } from \"./exports1\";\na;\nb;",
//         "import { A, b, B, C, type Y, type Z } from \"./exports1\";\na;\nb;",
//     }, &.{.OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderLast});
    _ = f.GoToMarker(undefined, "1a");
    // try f.VerifyImportFixAtPosition(undefined, &.{
//         "import { a, A, B, C, type Y, type Z } from \"./exports1\";\na;\nb;",
//         "import { A, b, B, C, type Y, type Z } from \"./exports1\";\na;\nb;",
//     }, &.{.OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderLast});
    _ = f.GoToMarker(undefined, "1b");
    // try f.VerifyImportFixAtPosition(undefined, &.{
//         "import { a, A, B, C, type Y, type Z } from \"./exports1\";\na;\nb;",
//         "import { A, b, B, C, type Y, type Z } from \"./exports1\";\na;\nb;",
//     }, &.{.OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderInline});
    _ = f.GoToMarker(undefined, "1c");
    // try f.VerifyImportFixAtPosition(undefined, &.{
//         "import { a, A, B, C, type Y, type Z } from \"./exports1\";\na;\nb;",
//         "import { A, b, B, C, type Y, type Z } from \"./exports1\";\na;\nb;",
//     }, &.{.OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderInline});
    _ = f.GoToMarker(undefined, "2");
    // try f.VerifyImportFixAtPosition(undefined, &.{
//         "import { A, a, B, b, type Y, type Z } from \"./exports1\";\nimport { d, E } from \"./exports2\";\nd",
//     }, &.{.OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderLast});
    _ = f.GoToMarker(undefined, "2a");
    // try f.VerifyImportFixAtPosition(undefined, &.{
//         "import { A, a, B, b, type Y, type Z } from \"./exports1\";\nimport { E, d } from \"./exports2\";\nd",
//     }, &.{.OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderLast});
    _ = f.GoToMarker(undefined, "2b");
    // try f.VerifyImportFixAtPosition(undefined, &.{
//         "import { A, a, B, b, type Y, type Z } from \"./exports1\";\nimport { d, E } from \"./exports2\";\nd",
//     }, &.{.OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderLast});
    _ = f.GoToMarker(undefined, "2c");
    // try f.VerifyImportFixAtPosition(undefined, &.{
//         "import { A, a, B, b, type Y, type Z } from \"./exports1\";\nimport { E, d } from \"./exports2\";\nd",
//     }, &.{.OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderLast});
}

test "TestAutoImportNodeModuleSymlinkRenamed" {
    const content =
        \\// @Filename: /home/src/workspaces/solution/package.json
        \\{
        \\    "name": "monorepo",
        \\    "workspaces": ["packages/*"]
        \\}
        \\// @Filename: /home/src/workspaces/solution/packages/utils/package.json
        \\{
        \\    "name": "utils",
        \\    "version": "1.0.0",
        \\    "exports": "./dist/index.js"
        \\}
        \\// @Filename: /home/src/workspaces/solution/packages/utils/tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "lib": ["es5"],
        \\        "composite": true,
        \\        "module": "nodenext",
        \\        "rootDir": "src",
        \\        "outDir": "dist"
        \\    },
        \\    "include": ["src"]
        \\}
        \\// @Filename: /home/src/workspaces/solution/packages/utils/src/index.ts
        \\export function gainUtility() { return 0; }
        \\// @Filename: /home/src/workspaces/solution/packages/web/package.json
        \\{
        \\    "name": "web",
        \\    "version": "1.0.0",
        \\    "dependencies": {
        \\        "@monorepo/utils": "file:../utils"
        \\    }
        \\}
        \\// @Filename: /home/src/workspaces/solution/packages/web/tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "lib": ["es5"],
        \\        "composite": true,
        \\        "module": "esnext",
        \\        "moduleResolution": "bundler",
        \\        "rootDir": "src",
        \\        "outDir": "dist",
        \\        "emitDeclarationOnly": true
        \\    },
        \\    "include": ["src"],
        \\    "references": [
        \\        { "path": "../utils" }
        \\    ]
        \\}
        \\// @Filename: /home/src/workspaces/solution/packages/web/src/index.ts
        \\gainUtility/**/
        \\// @link: /home/src/workspaces/solution/packages/utils -> /home/src/workspaces/solution/node_modules/utils
        \\// @link: /home/src/workspaces/solution/packages/utils -> /home/src/workspaces/solution/node_modules/@monorepo/utils
        \\// @link: /home/src/workspaces/solution/packages/web -> /home/src/workspaces/solution/node_modules/web
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToMarker(undefined, "");
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"@monorepo/utils"}, null );
}

test "TestCompletionsGenericUnconstrained" {
    const content =
        \\// @strict: true
        \\function f<T>(x: T) {
        \\  return x;
        \\}
        \\
        \\f({ /**/ });
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
//                     .Label =    "Object",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestRenameDestructuringClassProperty" {
    const content =
        \\class A {
        \\    [|[|{| "contextRangeIndex": 0 |}foo|]: string;|]
        \\}
        \\class B {
        \\    syntax1(a: A): void {
        \\        [|let { [|{| "contextRangeIndex": 2 |}foo|] } = a;|]
        \\    }
        \\    syntax2(a: A): void {
        \\        [|let { [|{| "contextRangeIndex": 4 |}foo|]: foo } = a;|]
        \\    }
        \\    syntax11(a: A): void {
        \\        [|let { [|{| "contextRangeIndex": 6 |}foo|] } = a;|]
        \\        [|foo|] = "newString";
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[1], f.Ranges()[5], f.Ranges()[3], f.Ranges()[7], f.Ranges()[8]);
}

test "TestFormattingObjectLiteralOpenCurlyNewlineAssignment" {
    const content =
        \\
        \\var obj = {};
        \\obj =
        \\{
        \\    prop: 3
        \\};
        \\ 
        \\var obj2 = obj ||
        \\{
        \\    prop: 0
        \\}
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    try f.VerifyCurrentFileContent(undefined, "\nvar obj = {};\nobj =\n{\n    prop: 3\n};\n\nvar obj2 = obj ||\n{\n    prop: 0\n}\n");
    // f.GetOptions();
    // f.Configure(undefined, opts400);
    _ = f.FormatDocument(undefined, "");
    try f.VerifyCurrentFileContent(undefined, "\nvar obj = {};\nobj =\n    {\n        prop: 3\n    };\n\nvar obj2 = obj ||\n    {\n        prop: 0\n    }\n");
}

test "TestFindAllRefsReExportRightNameWrongSymbol" {
    const content =
        \\// @Filename: /a.ts
        \\[|export const /*a*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 0 |}x|] = 0;|]
        \\// @Filename: /b.ts
        \\[|export const /*b*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 2 |}x|] = 0;|]
        \\//@Filename: /c.ts
        \\[|export { /*cFromB*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 4 |}x|] } from "./b";|]
        \\[|import { /*cFromA*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 6 |}x|] } from "./a";|]
        \\/*cUse*/[|x|];
        \\// @Filename: /d.ts
        \\[|import { /*d*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 9 |}x|] } from "./c";|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyNoErrors(undefined);
    // try f.VerifyBaselineFindAllReferences(undefined, "a", "b", "cFromB", "cFromA", "cUse", "d");
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[1]);
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[7], f.Ranges()[8]);
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[3]);
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[5]);
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[10]);
}

test "TestAsConstRefsNoErrors2" {
    const content =
        \\class Tex {
        \\    type = </**/const>'Text';
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "");
    try f.VerifyNoErrors(undefined);
}

test "TestSemanticModernClassificationMembers" {
    const content =
        \\class A {
        \\  static x = 9;
        \\  f = 9;
        \\  async m() { return A.x + await this.m(); };
        \\  get s() { return this.f; 
        \\  static t() { return new A().f; };
        \\  constructor() {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "class.declaration", .Text = "A"},
//         .{.Type = "property.declaration.static", .Text = "x"},
//         .{.Type = "property.declaration", .Text = "f"},
//         .{.Type = "method.declaration.async", .Text = "m"},
//         .{.Type = "class", .Text = "A"},
//         .{.Type = "property.static", .Text = "x"},
//         .{.Type = "method.async", .Text = "m"},
//         .{.Type = "property.declaration", .Text = "s"},
//         .{.Type = "property", .Text = "f"},
//         .{.Type = "method.declaration.static", .Text = "t"},
//         .{.Type = "class", .Text = "A"},
//         .{.Type = "property", .Text = "f"},
//     });
}

test "TestGetNavigationBarItems" {
    const content =
        \\class C {
        \\    foo;
        \\    ["bar"]: string;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestCompletionListInUnclosedCommaExpression02" {
    const content =
        \\// should NOT see a and b
        \\foo((a, b) => (a,/*1*/
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
//                 "a",
//                 "b",
//             },
//         },
//     });
}

test "TestReferencesForStatementKeywords" {
    const content =
        \\// @filename: /main.ts
        \\// import ... = ...
        \\[|{| "id": "importEqualsDecl1" |}/*importEqualsDecl1_importKeyword*/[|import|] [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeId": "importEqualsDecl1" |}A|] = /*importEqualsDecl1_requireKeyword*/[|require|]("[|{| "isWriteAccess": false, "isDefinition": false, "contextRangeId": "importEqualsDecl1" |}./a|]");|]
        \\[|{| "id": "namespaceDecl1" |}namespace [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeId": "namespaceDecl1" |}N|] { }|]
        \\[|{| "id": "importEqualsDecl2" |}/*importEqualsDecl2_importKeyword*/[|import|] [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeId": "importEqualsDecl2" |}N2|] = [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeId": "importEqualsDecl2" |}N|];|]
        \\
        \\// import ... from ...
        \\[|{| "id": "importDecl1" |}/*importDecl1_importKeyword*/[|import|] /*importDecl1_typeKeyword*/[|type|] [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeId": "importDecl1" |}B|] /*importDecl1_fromKeyword*/[|from|] "[|{| "isWriteAccess": false, "isDefinition": false, "contextRangeId": "importDecl1" |}./b|]";|]
        \\[|{| "id": "importDecl2" |}/*importDecl2_importKeyword*/[|import|] /*importDecl2_typeKeyword*/[|type|] * /*importDecl2_asKeyword*/[|as|] [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeId": "importDecl2" |}C|] /*importDecl2_fromKeyword*/[|from|] "[|{| "isWriteAccess": false, "isDefinition": false, "contextRangeId": "importDecl2" |}./c|]";|]
        \\[|{| "id": "importDecl3" |}/*importDecl3_importKeyword*/[|import|] /*importDecl3_typeKeyword*/[|type|] { [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeId": "importDecl3" |}D|] } /*importDecl3_fromKeyword*/[|from|] "[|{| "isWriteAccess": false, "isDefinition": false, "contextRangeId": "importDecl3" |}./d|]";|]
        \\[|{| "id": "importDecl4" |}/*importDecl4_importKeyword*/[|import|] /*importDecl4_typeKeyword*/[|type|] { e1, e2 /*importDecl4_asKeyword*/[|as|] [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeId": "importDecl4" |}e3|] } /*importDecl4_fromKeyword*/[|from|] "[|{| "isWriteAccess": false, "isDefinition": false, "contextRangeId": "importDecl4" |}./e|]";|]
        \\
        \\// import "module"
        \\[|{| "id": "importDecl5" |}/*importDecl5_importKeyword*/[|import|] "[|{| "isWriteAccess": false, "isDefinition": false, "contextRangeId": "importDecl5" |}./f|]";|]
        \\
        \\// export ... from ...
        \\[|{| "id": "exportDecl1" |}/*exportDecl1_exportKeyword*/[|export|] /*exportDecl1_typeKeyword*/[|type|] * /*exportDecl1_fromKeyword*/[|from|] "[|{| "isWriteAccess": false, "isDefinition": false, "contextRangeId": "exportDecl1" |}./g|]";|]
        \\[|{| "id": "exportDecl2" |}/*exportDecl2_exportKeyword*/[|export|] /*exportDecl2_typeKeyword*/[|type|] [|{| "id": "exportDecl2_namespaceExport" |}* /*exportDecl2_asKeyword*/[|as|] [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeId": "exportDecl2" |}H|]|] /*exportDecl2_fromKeyword*/[|from|] "[|{| "isWriteAccess": false, "isDefinition": false, "contextRangeId": "exportDecl2" |}./h|]";|]
        \\[|{| "id": "exportDecl3" |}/*exportDecl3_exportKeyword*/[|export|] /*exportDecl3_typeKeyword*/[|type|] { [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeId": "exportDecl3" |}I|] } /*exportDecl3_fromKeyword*/[|from|] "[|{| "isWriteAccess": false, "isDefinition": false, "contextRangeId": "exportDecl3" |}./i|]";|]
        \\[|{| "id": "exportDecl4" |}/*exportDecl4_exportKeyword*/[|export|] /*exportDecl4_typeKeyword*/[|type|] { j1, j2 /*exportDecl4_asKeyword*/[|as|] [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeId": "exportDecl4" |}j3|] } /*exportDecl4_fromKeyword*/[|from|] "[|{| "isWriteAccess": false, "isDefinition": false, "contextRangeId": "exportDecl4" |}./j|]";|]
        \\[|{| "id": "typeDecl1" |}type [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeId": "typeDecl1" |}Z1|] = 1;|]
        \\[|{| "id": "exportDecl5" |}/*exportDecl5_exportKeyword*/[|export|] /*exportDecl5_typeKeyword*/[|type|] { [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeId": "exportDecl5" |}Z1|] };|]
        \\type Z2 = 2;
        \\type Z3 = 3;
        \\[|{| "id": "exportDecl6" |}/*exportDecl6_exportKeyword*/[|export|] /*exportDecl6_typeKeyword*/[|type|] { z2, z3 /*exportDecl6_asKeyword*/[|as|] [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeId": "exportDecl6" |}z4|] };|]
        \\// @filename: /main2.ts
        \\[|{| "id": "varDecl1" |}const [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeId": "varDecl1" |}x|] = {};|]
        \\[|{| "id": "exportAssignment1" |}/*exportAssignment1_exportKeyword*/[|export|] = [|{| "isWriteAccess": false, "isDefinition": false, "contextRangeId": "exportAssignment1"|}x|];|]
        \\// @filename: /main3.ts
        \\[|{| "id": "varDecl3" |}const [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeId": "varDecl3" |}y|] = {};|]
        \\[|{| "id": "exportAssignment2" |}/*exportAssignment2_exportKeyword*/[|export|] [|default|] [|{| "isWriteAccess": false, "isDefinition": false, "contextRangeId": "exportAssignment2"|}y|];|]
        \\// @filename: /a.ts
        \\export const a = 1;
        \\// @filename: /b.ts
        \\[|{| "id": "classDecl1" |}export default class [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeId": "classDecl1" |}B|] {}|]
        \\// @filename: /c.ts
        \\export const c = 1;
        \\// @filename: /d.ts
        \\[|{| "id": "classDecl2" |}export class [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeId": "classDecl2" |}D|] {}|]
        \\// @filename: /e.ts
        \\export const e1 = 1;
        \\export const e2 = 2;
        \\// @filename: /f.ts
        \\export const f = 1;
        \\// @filename: /g.ts
        \\export const g = 1;
        \\// @filename: /h.ts
        \\export const h = 1;
        \\// @filename: /i.ts
        \\[|{| "id": "classDecl3" |}export class [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeId": "classDecl3" |}I|] {}|]
        \\// @filename: /j.ts
        \\export const j1 = 1;
        \\export const j2 = 2;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "importEqualsDecl1_importKeyword", "importEqualsDecl1_requireKeyword", "importEqualsDecl2_importKeyword", "importDecl1_importKeyword", "importDecl1_typeKeyword", "importDecl1_fromKeyword", "importDecl2_importKeyword", "importDecl2_typeKeyword", "importDecl2_asKeyword", "importDecl2_fromKeyword", "importDecl3_importKeyword", "importDecl3_typeKeyword", "importDecl3_fromKeyword", "importDecl4_importKeyword", "importDecl4_typeKeyword", "importDecl4_fromKeyword", "importDecl4_asKeyword", "importDecl5_importKeyword", "exportDecl1_exportKeyword", "exportDecl1_typeKeyword", "exportDecl1_fromKeyword", "exportDecl2_exportKeyword", "exportDecl2_typeKeyword", "exportDecl2_asKeyword", "exportDecl2_fromKeyword", "exportDecl3_exportKeyword", "exportDecl3_typeKeyword", "exportDecl3_fromKeyword", "exportDecl4_exportKeyword", "exportDecl4_typeKeyword", "exportDecl4_fromKeyword", "exportDecl4_asKeyword", "exportDecl5_exportKeyword", "exportDecl5_typeKeyword", "exportDecl6_exportKeyword", "exportDecl6_typeKeyword", "exportDecl6_asKeyword", "exportAssignment1_exportKeyword", "exportAssignment2_exportKeyword");
}

test "TestCompletionListWithAmbientDeclaration" {
    const content =
        \\declare module "http" {
        \\   var x;
        \\   /*1*/
        \\}
        \\declare module 'https' {
        \\}
        \\/*2*/
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
//                 "http",
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
//                 "http",
//                 "https",
//             },
//         },
//     });
}

test "TestImportFixes_quotePreferenceSingle_importHelpers" {
    const content =
        \\// @importHelpers: true
        \\// @filename: /a.ts
        \\export default () => {};
        \\// @filename: /b.ts
        \\export default () => {};
        \\// @filename: /test.ts
        \\import a from './a';
        \\[|b|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/test.ts");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import b from './b';\nb",
    }, null );
}

test "TestCompletionListInvalidMemberNames_withExistingIdentifier" {
    const content =
        \\declare const x: { "foo ": "space in the name", };
        \\x[|.fo/*0*/|];
        \\x[|./*1*/|]
        \\unrelatedIdentifier;
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
//             .Exact = &.{
//                 &.{
//                     .Label =      "foo ",
//                     .InsertText = undefined("[\"foo \"]"),
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
//             .Exact = &.{
//                 &.{
//                     .Label =      "foo ",
//                     .InsertText = undefined("[\"foo \"]"),
//                 },
//             },
//         },
//     });
}

test "TestGetOutliningSpansDepthChainedCalls" {
    const content =
        \\declare var router: any;
        \\router
        \\    .get[|("/", async(ctx) =>[|{
        \\        ctx.body = "base";
        \\    }|])|]
        \\    .post[|("/a", async(ctx) =>[|{
        \\        //a
        \\    }|])|]
        \\    .get[|("/", async(ctx) =>[|{
        \\        ctx.body = "base";
        \\    }|])|]
        \\    .post[|("/a", async(ctx) =>[|{
        \\        //a
        \\    }|])|]
        \\    .get[|("/", async(ctx) =>[|{
        \\        ctx.body = "base";
        \\    }|])|]
        \\    .post[|("/a", async(ctx) =>[|{
        \\        //a
        \\    }|])|]
        \\    .get[|("/", async(ctx) =>[|{
        \\        ctx.body = "base";
        \\    }|])|]
        \\    .post[|("/a", async(ctx) =>[|{
        \\        //a
        \\    }|])|]
        \\    .get[|("/", async(ctx) =>[|{
        \\        ctx.body = "base";
        \\    }|])|]
        \\    .post[|("/a", async(ctx) =>[|{
        \\        //a
        \\    }|])|]
        \\    .get[|("/", async(ctx) =>[|{
        \\        ctx.body = "base";
        \\    }|])|]
        \\    .post[|("/a", async(ctx) =>[|{
        \\        //a
        \\    }|])|]
        \\    .get[|("/", async(ctx) =>[|{
        \\        ctx.body = "base";
        \\    }|])|]
        \\    .post[|("/a", async(ctx) =>[|{
        \\        //a
        \\    }|])|]
        \\    .get[|("/", async(ctx) =>[|{
        \\        ctx.body = "base";
        \\    }|])|]
        \\    .post[|("/a", async(ctx) =>[|{
        \\        //a
        \\    }|])|]
        \\    .get[|("/", async(ctx) =>[|{
        \\        ctx.body = "base";
        \\    }|])|]
        \\    .post[|("/a", async(ctx) =>[|{
        \\        //a
        \\    }|])|]
        \\    .get[|("/", async(ctx) =>[|{
        \\        ctx.body = "base";
        \\    }|])|]
        \\    .post[|("/a", async(ctx) =>[|{
        \\        //a
        \\    }|])|]
        \\    .get[|("/", async(ctx) =>[|{
        \\        ctx.body = "base";
        \\    }|])|]
        \\    .post[|("/a", async(ctx) =>[|{
        \\        //a
        \\    }|])|]
        \\    .get[|("/", async(ctx) =>[|{
        \\        ctx.body = "base";
        \\    }|])|]
        \\    .post[|("/a", async(ctx) =>[|{
        \\        //a
        \\    }|])|]
        \\    .get[|("/", async(ctx) =>[|{
        \\        ctx.body = "base";
        \\    }|])|]
        \\    .post[|("/a", async(ctx) =>[|{
        \\        //a
        \\    }|])|]
        \\    .get[|("/", async(ctx) =>[|{
        \\        ctx.body = "base";
        \\    }|])|]
        \\    .post[|("/a", async(ctx) =>[|{
        \\        //a
        \\    }|])|]
        \\    .get[|("/", async(ctx) =>[|{
        \\        ctx.body = "base";
        \\    }|])|]
        \\    .post[|("/a", async(ctx) =>[|{
        \\        //a
        \\    }|])|]
        \\    .get[|("/", async(ctx) =>[|{
        \\        ctx.body = "base";
        \\    }|])|]
        \\    .post[|("/a", async(ctx) =>[|{
        \\        //a
        \\    }|])|]
        \\    .get[|("/", async(ctx) =>[|{
        \\        ctx.body = "base";
        \\    }|])|]
        \\    .post[|("/a", async(ctx) =>[|{
        \\        //a
        \\    }|])|]
        \\    .get[|("/", async(ctx) =>[|{
        \\        ctx.body = "base";
        \\    }|])|]
        \\    .post[|("/a", async(ctx) =>[|{
        \\        //a
        \\    }|])|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyOutliningSpans(undefined);
}

test "TestCompletionsImport_duplicatePackages_scopedTypes" {
    const content =
        \\// @lib: es5
        \\// @module: commonjs
        \\// @esModuleInterop: true
        \\// @Filename: /node_modules/@types/scope__react-dom/package.json
        \\{ "name": "react-dom", "version": "1.0.0", "types": "./index.d.ts" }
        \\// @Filename: /node_modules/@types/scope__react-dom/index.d.ts
        \\import * as React from "react";
        \\export function render(): void;
        \\// @Filename: /node_modules/@types/scope__react/package.json
        \\{ "name": "react", "version": "1.0.0", "types": "./index.d.ts" }
        \\// @Filename: /node_modules/@types/scope__react/index.d.ts
        \\import "./other";
        \\export declare function useState(): void;
        \\// @Filename: /node_modules/@types/scope__react/other.d.ts
        \\export declare function useRef(): void;
        \\// @Filename: /packages/a/node_modules/@types/scope__react/package.json
        \\{ "name": "react", "version": "1.0.1", "types": "./index.d.ts" }
        \\// @Filename: /packages/a/node_modules/@types/scope__react/index.d.ts
        \\export declare function useState(): void;
        \\// @Filename: /packages/a/index.ts
        \\import "@scope/react-dom";
        \\import "@scope/react";
        \\// @Filename: /packages/a/foo.ts
        \\/**/
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
//             .Exact = CompletionGlobalsPlus(
//                 &.{
//                     &.{
//                         .Label = "render",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "@scope/react-dom",
//                             },
//                         },
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     },
//                     &.{
//                         .Label = "useState",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "@scope/react",
//                             },
//                         },
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     },
//                 }, false,
//             ),
//         },
//     });
}

test "TestFormattingComma" {
    const content =
        \\var x = [1 , 2];/*x*/
        \\var y = ( 1  , 2 );/*y*/
        \\var z1 = 1 , zz = 2;/*z1*/
        \\var z2 = {
        \\    x: 1 ,/*z2*/
        \\    y: 2
        \\};
        \\var z3 = (
        \\    () => { }  ,/*z3*/
        \\    () => { }
        \\    );
        \\var z4 = [
        \\    () => { } ,/*z4*/
        \\    () => { }
        \\];
        \\var z5 = {
        \\    x: () => { } ,/*z5*/
        \\    y: () => { }
        \\}; 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "x");
    try f.VerifyCurrentLineContent(undefined, "var x = [1, 2];");
    _ = f.GoToMarker(undefined, "y");
    try f.VerifyCurrentLineContent(undefined, "var y = (1, 2);");
    _ = f.GoToMarker(undefined, "z1");
    try f.VerifyCurrentLineContent(undefined, "var z1 = 1, zz = 2;");
    _ = f.GoToMarker(undefined, "z2");
    try f.VerifyCurrentLineContent(undefined, "    x: 1,");
    _ = f.GoToMarker(undefined, "z3");
    try f.VerifyCurrentLineContent(undefined, "    () => { },");
    _ = f.GoToMarker(undefined, "z4");
    try f.VerifyCurrentLineContent(undefined, "    () => { },");
    _ = f.GoToMarker(undefined, "z5");
    try f.VerifyCurrentLineContent(undefined, "    x: () => { },");
}

test "TestFindAllRefsThisKeywordMultipleFiles" {
    const content =
        \\// @Filename: file1.ts
        \\/*1*/this; /*2*/this;
        \\// @Filename: file2.ts
        \\/*3*/this;
        \\/*4*/this;
        \\// @Filename: file3.ts
        \\ ((x = /*5*/this, y) => /*6*/this)(/*7*/this, /*8*/this);
        \\ // different 'this'
        \\ function f(this) { return this; }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5", "6", "7", "8");
}

test "TestFindAllRefsReExport_broken2" {
    const content =
        \\// @Filename: /a.ts
        \\/*1*/export { /*2*/x } from "nonsense";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestFindAllRefsParameterPropertyDeclaration3" {
    const content =
        \\class Foo {
        \\    constructor(protected /*0*/protectedParam: number) {
        \\        let localProtected = /*1*/protectedParam;
        \\        this./*2*/protectedParam += 10;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "0", "1", "2");
}

test "TestCompletionListInUnclosedSpreadExpression01" {
    const content =
        \\var x;
        \\var y = [1,2,.../*1*/
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

test "TestEsModuleInteropFindAllReferences2" {
    const content =
        \\// @esModuleInterop: true
        \\// @Filename: /a.d.ts
        \\export as namespace abc;
        \\/*1*/export const /*2*/x: number;
        \\// @Filename: /b.ts
        \\import a from "./a";
        \\a./*3*/x;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestInstanceTypesForGenericType1" {
    const content =
        \\class G<T> {               // Introduce type parameter T
        \\    self: G<T>;            // Use T as type argument to form instance type
        \\    f() {
        \\        this./*1*/self = /*2*/this;  // self and this are both of type G<T>
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "(property) G<T>.self: G<T>", "");
    try f.VerifyQuickInfoAt(undefined, "2", "this: this", "");
}

test "TestCompletionOfAwaitPromise5" {
    const content =
        \\interface Foo { foo: string }
        \\async function foo(x: (a: number) => Promise<Foo>) {
        \\   [|x(1)./**/|]
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
//                     .Label =      "foo",
//                     .InsertText = undefined("(await x(1)).foo"),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "foo",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestExtendInterfaceOverloadedMethod" {
    const content =
        \\// @strict: false
        \\interface A<T> {
        \\    foo(a: T): B<T>;
        \\    foo(): void ;
        \\    foo2(): B<number>;
        \\}
        \\interface B<T> extends A<T> {
        \\    bar(): void ;
        \\}
        \\var b: B<number>;
        \\var /**/x = b.foo2().foo(5).foo(); // 'x' is of type 'void'
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "var x: void", "");
    try f.VerifyNoErrors(undefined);
}

test "TestCodeFixMissingTypeAnnotationOnExports30_inline_import" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\// @Filename: /person-code.ts
        \\export type Person = { x: string; }
        \\export function getPerson() : Person {
        \\  return null!
        \\}
        \\// @Filename: /code.ts
        \\import { getPerson } from "./person-code";
        \\export const exp = {
        \\  person: getPerson()
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/code.ts");
    try f.VerifyCodeFix(undefined, .{
        .Description = "Add satisfies and an inline type assertion with 'Person'",
        .NewFileContent = "import { getPerson, Person } from \"./person-code\";\nexport const exp = {\n  person: getPerson() satisfies Person as Person\n};",
        .Index = 1,
    });
}

test "TestCompletionOfAwaitPromise6" {
    const content =
        \\// @lib: es2015
        \\async function foo(x: Promise<string>) {
        \\   [|x./**/|]
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
//                 "catch",
//                 "then",
//             },
//         },
//     });
}

test "TestUnusedImports12FS" {
    const content =
        \\// @noUnusedLocals: true
        \\// @Filename: file2.ts
        \\[| import f1, * as s from "./file1"; |]
        \\f1(42);
        \\// @Filename: file1.ts
        \\export function f1(n: number){}
        \\export function f2(s: string){};
        \\export default f1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyRangeAfterCodeFix(undefined, "import f1 from \"./file1\";", false, 0, 0);
}

test "TestRemoveDeclareKeyword" {
    const content =
        \\/**/declare var y;
        \\var x = new y;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.DeleteAtCaret(undefined, 7);
}

test "TestFormattingObjectLiteral" {
    const content =
        \\var clear = {
        \\"a": 1/**/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "");
    try f.VerifyCurrentLineContent(undefined, "    \"a\": 1");
}

test "TestCodeFixClassImplementInterfaceTypeLiterals" {
    const content =
        \\type Builtin = Date | Function | Uint8Array | string | number | boolean | undefined;
        \\
        \\export type DeepPartial<T> = T extends Builtin ? T :
        \\    T extends Array<infer U> ? Array<DeepPartial<U>> :
        \\        T extends ReadonlyArray<infer U> ? ReadonlyArray<DeepPartial<U>> :
        \\            T extends {} ? { [K in keyof T]?: DeepPartial<T[K]> } : Partial<T>;
        \\
        \\export interface Nested {
        \\    field: string;
        \\}
        \\
        \\interface Foo {
        \\    request(): DeepPartial<{ nested1: Nested; test2: Nested }>;
        \\}
        \\[|export class C implements Foo {}|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'Foo'",
        .NewRangeContent = "export class C implements Foo {\n    request(): DeepPartial<{ nested1: Nested; test2: Nested; }> {\n        throw new Error(\"Method not implemented.\");\n    }\n}",
        .Index = 0,
    });
}

test "TestGoToDefinitionInstanceof1" {
    const content =
        \\// @lib: es5
        \\class /*end*/ C {
        \\}
        \\declare var obj: any;
        \\obj [|/*start*/instanceof|] C;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "start");
}

test "TestFormatTypeArgumentOnNewLine" {
    const content =
        \\const genericObject = new GenericObject<
        \\  /*1*/{}
        \\>();
        \\const genericObject2 = new GenericObject2<
        \\  /*2*/{},
        \\  /*3*/{}
        \\>();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCurrentLineContent(undefined, "    {}");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyCurrentLineContent(undefined, "    {},");
    _ = f.GoToMarker(undefined, "3");
    try f.VerifyCurrentLineContent(undefined, "    {}");
}

test "TestInlayHintsInteractiveAnyParameter1" {
    const content =
        \\function foo (v: any) {}
        \\foo(1);
        \\foo('');
        \\foo(true);
        \\foo(foo);
        \\foo((1));
        \\foo(foo(1));
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayParameterNameHints = lsutil.IncludeInlayParameterNameHintsLiterals}});
}

test "TestGetOccurrencesConstructor" {
    const content =
        \\class C {
        \\    [|const/**/ructor|]();
        \\    [|constructor|](x: number);
        \\    [|constructor|](y: string, x: number);
        \\    [|constructor|](a?: any, ...r: any[]) {
        \\        if (a === undefined && r.length === 0) {
        \\            return;
        \\        }
        \\
        \\        return;
        \\    }
        \\}
        \\
        \\class D {
        \\    constructor(public x: number, public y: number) {
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestImportNameCodeFix_uriStyleNodeCoreModules3" {
    const content =
        \\// @module: commonjs
        \\// @Filename: /node_modules/@types/node/index.d.ts
        \\declare module "path" { function join(...segments: readonly string[]): string; }
        \\declare module "node:path" { export * from "path"; }
        \\declare module "fs" { function writeFile(): void }
        \\declare module "fs/promises" { function writeFile(): Promise<void> }
        \\declare module "node:fs" { export * from "fs"; }
        \\declare module "node:fs/promises" { export * from "fs/promises"; }
        \\// @Filename: /other.ts
        \\import "node:fs/promises";
        \\// @Filename: /noPrefix.ts
        \\import "path";
        \\writeFile/*noPrefix*/
        \\// @Filename: /prefix.ts
        \\import "node:path";
        \\writeFile/*prefix*/
        \\// @Filename: /mixed1.ts
        \\import "path";
        \\import "node:path";
        \\writeFile/*mixed1*/
        \\// @Filename: /mixed2.ts
        \\import "node:path";
        \\import "path";
        \\writeFile/*mixed2*/
        \\// @Filename: /test1.ts
        \\import "node:test";
        \\import "path";
        \\writeFile/*test1*/
        \\// @Filename: /test2.ts
        \\import "node:test";
        \\writeFile/*test2*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyImportFixModuleSpecifiers(undefined, "noPrefix", &.{"fs", "fs/promises"}, null );
    // try f.VerifyImportFixModuleSpecifiers(undefined, "prefix", &.{"node:fs", "node:fs/promises"}, null );
    // try f.VerifyImportFixModuleSpecifiers(undefined, "mixed1", &.{"node:fs", "node:fs/promises"}, null );
    // try f.VerifyImportFixModuleSpecifiers(undefined, "mixed2", &.{"node:fs", "node:fs/promises"}, null );
    // try f.VerifyImportFixModuleSpecifiers(undefined, "test1", &.{"fs", "fs/promises"}, null );
    // try f.VerifyImportFixModuleSpecifiers(undefined, "test2", &.{"node:fs", "node:fs/promises"}, null );
}

test "TestFindAllRefsJsDocTemplateTag_function_js" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\/**
        \\ * @template /*1*/T
        \\ * @return {/*2*/T}
        \\ */
        \\function f() {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestFormatDotAfterNumber" {
    const content =
        \\1+ 2 .toString() +3/*1*/
        \\1+ 2. .toString() +3/*2*/
        \\1+ 2.0 .toString() +3/*3*/
        \\1+ (2) .toString() +3/*4*/
        \\1+ 2_000 .toString() +3/*5*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCurrentLineContent(undefined, "1 + 2 .toString() + 3");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyCurrentLineContent(undefined, "1 + 2..toString() + 3");
    _ = f.GoToMarker(undefined, "3");
    try f.VerifyCurrentLineContent(undefined, "1 + 2.0.toString() + 3");
    _ = f.GoToMarker(undefined, "4");
    try f.VerifyCurrentLineContent(undefined, "1 + (2).toString() + 3");
    _ = f.GoToMarker(undefined, "5");
    try f.VerifyCurrentLineContent(undefined, "1 + 2_000 .toString() + 3");
}

test "TestNoSignatureHelpOnNewKeyword" {
    const content =
        \\class Foo { }
        \\new/*1*/ Foo
        \\new /*2*/Foo(/*3*/)
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyNoSignatureHelpForMarkers(undefined, "1", "2");
    _ = f.GoToMarker(undefined, "3");
    // try f.VerifySignatureHelp(undefined, .{.Text = "Foo(): Foo"});
}

test "TestExportEqualTypes" {
    const content =
        \\// @module: commonjs
        \\// @lib: es5
        \\// @strict: false
        \\// @Filename: exportEqualTypes_file0.ts
        \\interface x {
        \\    (): Date;
        \\    foo: string;
        \\}
        \\export = x;
        \\// @Filename: exportEqualTypes_file1.ts
        \\///<reference path='exportEqualTypes_file0.ts'/>
        \\import test = require('./exportEqualTypes_file0');
        \\var t: /*1*/test;  // var 't' should be of type 'test'
        \\var /*2*/r1 = t(); // Should return a Date
        \\var /*3*/r2 = t./*4*/foo; // t should have 'foo' in dropdown list and be of type 'string'
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "(alias) interface test\nimport test = require('./exportEqualTypes_file0')", "");
    try f.VerifyQuickInfoAt(undefined, "2", "var r1: Date", "");
    try f.VerifyQuickInfoAt(undefined, "3", "var r2: string", "");
    // f.VerifyCompletions(undefined, "4", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionFunctionMembersWithPrototypePlus(
//                 &.{
//                     "foo",
//                 },
//             ),
//         },
//     });
    try f.VerifyNoErrors(undefined);
}

test "TestCodeFixClassImplementInterfaceMemberTypeAlias" {
    const content =
        \\type MyType = [string, number];
        \\interface I { x: MyType; test(a: MyType): void; }
        \\class C implements I {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'I'",
        .NewFileContent = "type MyType = [string, number];\ninterface I { x: MyType; test(a: MyType): void; }\nclass C implements I {\n    x: MyType;\n    test(a: MyType): void {\n        throw new Error(\"Method not implemented.\");\n    }\n}",
        .Index = 0,
    });
}

test "TestCodeFixAmbientClassImplementClassMethodViaHeritage" {
    const content =
        \\class C1 {
        \\    f1() {}
        \\}
        \\
        \\class C2 extends C1 {
        \\
        \\}
        \\
        \\declare class C3 implements C2 {[|
        \\    |]f2();
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyRangeAfterCodeFix(undefined, "f1(): void;\n", false, 0, 0);
}

test "TestGoToDefinitionSwitchCase2" {
    const content =
        \\switch (null) {
        \\  [|/*start*/default|]: break;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "start");
}

test "TestRenameForDefaultExport02" {
    const content =
        \\[|export default function /*1*/[|{| "contextRangeIndex": 0 |}DefaultExportedFunction|]() {
        \\    return /*2*/[|DefaultExportedFunction|]
        \\}|]
        \\/**
        \\ *  Commenting [|{| "inComment": true |}DefaultExportedFunction|]
        \\ */
        \\
        \\var x: typeof /*3*/[|DefaultExportedFunction|];
        \\
        \\var y = /*4*/[|DefaultExportedFunction|]();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, null , ToAny(core.Filter(f.GetRangesByText().Get("DefaultExportedFunction"), func(r *fourslash.RangeMarker) bool .{ return r.Marker == null || r.Marker.Data["inComment"] == null })));
}

test "TestReferencesForGlobals5" {
    const content =
        \\// @Filename: referencesForGlobals_1.ts
        \\namespace globalModule {
        \\    export var x;
        \\}
        \\
        \\/*1*/import /*2*/globalAlias = globalModule;
        \\// @Filename: referencesForGlobals_2.ts
        \\var m = /*3*/globalAlias;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestFormattingExpressionsInIfCondition" {
    const content =
        \\if (a === 1 ||
        \\    /*0*/b === 2 ||/*1*/
        \\    c === 3) {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, "\n");
    _ = f.GoToMarker(undefined, "0");
    try f.VerifyCurrentLineContent(undefined, "    b === 2 ||");
}

test "TestCompletionsImportDefaultExportCrash1" {
    const content =
        \\// @module: node18
        \\// @allowJs: true
        \\// @Filename: /node_modules/dom7/index.d.ts
        \\export interface Dom7Array {
        \\  length: number;
        \\  prop(propName: string): any;
        \\}
        \\
        \\export interface Dom7 {
        \\  (): Dom7Array;
        \\  fn: any;
        \\}
        \\
        \\declare const Dom7: Dom7;
        \\
        \\export {
        \\  Dom7 as $,
        \\};
        \\// @Filename: /dom7.js
        \\import * as methods from 'dom7';
        \\Object.keys(methods).forEach((methodName) => {
        \\  if (methodName === '$') return;
        \\  methods.$.fn[methodName] = methods[methodName];
        \\});
        \\
        \\export default methods.$;
        \\// @Filename: /swipe-back.js
        \\import $ from './dom7.js';
        \\/*1*/
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
//                     .Label = "$",
//                 },
//             },
//         },
//     });
}

test "TestNonExistingImport" {
    const content =
        \\// @lib: es5
        \\namespace m {
        \\    import foo = module(_foo);
        \\    var n: num/*1*/
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
//             .Exact = CompletionGlobalTypesPlus(
//                 &.{
//                     "foo",
//                 },
//             ),
//         },
//     });
}

test "TestCodeFixMissingTypeAnnotationOnExports38_unique_symbol_return" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\// @lib: es2019
        \\// @Filename: /code.ts
        \\const u: unique symbol = Symbol();
        \\export const fn = () => ({ u } as const);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Add return type '{ readonly u: typeof u; }'",
        .NewFileContent = "const u: unique symbol = Symbol();\nexport const fn = (): {\n    readonly u: typeof u;\n} => ({ u } as const);",
        .Index = 0,
    });
}

test "TestTsxCompletion13" {
    const content =
        \\//@Filename: file.tsx
        \\// @jsx: preserve
        \\// @skipLibCheck: true
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
        \\let opt = <MainButton /*1*/ />;
        \\let opt = <MainButton children="chidlren" /*2*/ />;
        \\let opt = <MainButton onClick={()=>{}} /*3*/ />;
        \\let opt = <MainButton onClick={()=>{}} ignore-prop /*4*/ />;
        \\let opt = <MainButton goTo="goTo" /*5*/ />;
        \\let opt = <MainButton wrong /*6*/ />;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"1", "6"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "goTo",
//                 "onClick",
//                 &.{
//                     .Label =      "children?",
//                     .InsertText = undefined("children"),
//                     .FilterText = undefined("children"),
//                     .Kind =       undefined(lsproto.CompletionItemKindField),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//                 &.{
//                     .Label =      "className?",
//                     .InsertText = undefined("className"),
//                     .FilterText = undefined("className"),
//                     .Kind =       undefined(lsproto.CompletionItemKindField),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
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
//                 "goTo",
//                 "onClick",
//                 &.{
//                     .Label =      "className?",
//                     .InsertText = undefined("className"),
//                     .FilterText = undefined("className"),
//                     .Kind =       undefined(lsproto.CompletionItemKindField),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"3", "4", "5"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =      "children?",
//                     .InsertText = undefined("children"),
//                     .FilterText = undefined("children"),
//                     .Kind =       undefined(lsproto.CompletionItemKindField),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//                 &.{
//                     .Label =      "className?",
//                     .InsertText = undefined("className"),
//                     .FilterText = undefined("className"),
//                     .Kind =       undefined(lsproto.CompletionItemKindField),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//             },
//         },
//     });
}

test "TestCallHierarchyTaggedTemplate" {
    const content =
        \\function foo() {
        \\    bar
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // try f.VerifyBaselineCallHierarchy(undefined);
}

test "TestReferencesForOverrides" {
    const content =
        \\namespace FindRef3 {
        \\    namespace SimpleClassTest {
        \\        export class Foo {
        \\            public /*foo*/foo(): void {
        \\            }
        \\        }
        \\        export class Bar extends Foo {
        \\            public foo(): void {
        \\            }
        \\        }
        \\    }
        \\
        \\    namespace SimpleInterfaceTest {
        \\        export interface IFoo {
        \\            /*ifoo*/ifoo(): void;
        \\        }
        \\        export interface IBar extends IFoo {
        \\            ifoo(): void;
        \\        }
        \\    }
        \\
        \\    namespace SimpleClassInterfaceTest {
        \\        export interface IFoo {
        \\            /*icfoo*/icfoo(): void;
        \\        }
        \\        export class Bar implements IFoo {
        \\            public icfoo(): void {
        \\            }
        \\        }
        \\    }
        \\
        \\    namespace Test {
        \\        export interface IBase {
        \\            /*field*/field: string;
        \\            /*method*/method(): void;
        \\        }
        \\
        \\        export interface IBlah extends IBase {
        \\            field: string;
        \\        }
        \\
        \\        export interface IBlah2 extends IBlah {
        \\            field: string;
        \\        }
        \\
        \\        export interface IDerived extends IBlah2 {
        \\            method(): void;
        \\        }
        \\
        \\        export class Bar implements IDerived {
        \\            public field: string;
        \\            public method(): void { }
        \\        }
        \\
        \\        export class BarBlah extends Bar {
        \\            public field: string;
        \\        }
        \\    }
        \\
        \\    function test() {
        \\        var x = new SimpleClassTest.Bar();
        \\        x.foo();
        \\
        \\        var y: SimpleInterfaceTest.IBar = null;
        \\        y.ifoo();
        \\
        \\        var w: SimpleClassInterfaceTest.Bar = null;
        \\        w.icfoo();
        \\
        \\        var z = new Test.BarBlah();
        \\        z.field = "";
        \\        z.method();
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "foo", "ifoo", "icfoo", "field", "method");
}

test "TestCompletionListInUnclosedForLoop02" {
    const content =
        \\for (let i = 0; i < 10; i++) /*1*/
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

test "TestFormattingOnObjectLiteral" {
    const content =
        \\var x = /*1*/{foo:/*2*/ 1,
        \\bar: "tt",/*3*/
        \\boo: /*4*/1 + 5}/*5*/;
        \\
        \\var x2 = /*6*/{foo/*7*/: 1,
        \\bar: /*8*/"tt",boo:1+5}/*9*/;
        \\
        \\function Foo() {/*10*/
        \\var typeICalc = {/*11*/
        \\clear: {/*12*/
        \\"()": [1, 2, 3]/*13*/
        \\}/*14*/
        \\}/*15*/
        \\}/*16*/
        \\
        \\// Rule for object literal members for the "value" of the memebr to follow the indent/*17*/
        \\// of the member, i.e. the relative position of the value is maintained when the member/*18*/
        \\// is indented./*19*/
        \\var x2 = {/*20*/
        \\  foo:/*21*/
        \\3,/*22*/
        \\          'bar':/*23*/
        \\                    { a: 1, b : 2}/*24*/
        \\};/*25*/
        \\
        \\var x={    };/*26*/
        \\var y = {};/*27*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCurrentLineContent(undefined, "var x = {");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyCurrentLineContent(undefined, "    foo: 1,");
    _ = f.GoToMarker(undefined, "3");
    try f.VerifyCurrentLineContent(undefined, "    bar: \"tt\",");
    _ = f.GoToMarker(undefined, "4");
    try f.VerifyCurrentLineContent(undefined, "    boo: 1 + 5");
    _ = f.GoToMarker(undefined, "5");
    try f.VerifyCurrentLineContent(undefined, "};");
    _ = f.GoToMarker(undefined, "6");
    try f.VerifyCurrentLineContent(undefined, "var x2 = {");
    _ = f.GoToMarker(undefined, "7");
    try f.VerifyCurrentLineContent(undefined, "    foo: 1,");
    _ = f.GoToMarker(undefined, "8");
    try f.VerifyCurrentLineContent(undefined, "    bar: \"tt\", boo: 1 + 5");
    _ = f.GoToMarker(undefined, "9");
    try f.VerifyCurrentLineContent(undefined, "};");
    _ = f.GoToMarker(undefined, "10");
    try f.VerifyCurrentLineContent(undefined, "function Foo() {");
    _ = f.GoToMarker(undefined, "11");
    try f.VerifyCurrentLineContent(undefined, "    var typeICalc = {");
    _ = f.GoToMarker(undefined, "12");
    try f.VerifyCurrentLineContent(undefined, "        clear: {");
    _ = f.GoToMarker(undefined, "13");
    try f.VerifyCurrentLineContent(undefined, "            \"()\": [1, 2, 3]");
    _ = f.GoToMarker(undefined, "14");
    try f.VerifyCurrentLineContent(undefined, "        }");
    _ = f.GoToMarker(undefined, "15");
    try f.VerifyCurrentLineContent(undefined, "    }");
    _ = f.GoToMarker(undefined, "16");
    try f.VerifyCurrentLineContent(undefined, "}");
    _ = f.GoToMarker(undefined, "17");
    try f.VerifyCurrentLineContent(undefined, "// Rule for object literal members for the \"value\" of the memebr to follow the indent");
    _ = f.GoToMarker(undefined, "18");
    try f.VerifyCurrentLineContent(undefined, "// of the member, i.e. the relative position of the value is maintained when the member");
    _ = f.GoToMarker(undefined, "19");
    try f.VerifyCurrentLineContent(undefined, "// is indented.");
    _ = f.GoToMarker(undefined, "20");
    try f.VerifyCurrentLineContent(undefined, "var x2 = {");
    _ = f.GoToMarker(undefined, "21");
    try f.VerifyCurrentLineContent(undefined, "    foo:");
    _ = f.GoToMarker(undefined, "22");
    try f.VerifyCurrentLineContent(undefined, "        3,");
    _ = f.GoToMarker(undefined, "23");
    try f.VerifyCurrentLineContent(undefined, "    'bar':");
    _ = f.GoToMarker(undefined, "24");
    try f.VerifyCurrentLineContent(undefined, "        { a: 1, b: 2 }");
    _ = f.GoToMarker(undefined, "25");
    try f.VerifyCurrentLineContent(undefined, "};");
    _ = f.GoToMarker(undefined, "26");
    try f.VerifyCurrentLineContent(undefined, "var x = {};");
    _ = f.GoToMarker(undefined, "27");
    try f.VerifyCurrentLineContent(undefined, "var y = {};");
}

test "TestQuickInfoOnUnionPropertiesWithIdenticalJSDocComments01" {
    const content =
        \\export type DocumentFilter = {
        \\    /** A language id, like 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestCompletionsAfterAsyncInObjectLiteral" {
    const content =
        \\const x: { m(): Promise<void> } = { async /**/ };
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
//                 "m",
//             },
//         },
//     });
}

test "TestFindAllRefsModuleDotExports" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\/*1*/const b = require("/*2*/./b");
        \\// @Filename: /b.js
        \\/*3*/module.exports = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestMemberlistOnDDot" {
    const content =
        \\var q = '';
        \\q/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, ".");
    _ = f.Insert(undefined, ".");
    _ = f.VerifyCompletions(undefined, null, null);
}

test "TestCodeFixClassImplementInterface_order" {
    const content =
        \\interface IFoo {
        \\  bar(): void;
        \\}
        \\
        \\class Foo implements IFoo {
        \\  private x = 1;
        \\  constructor() { this.x = 2 }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'IFoo'",
        .NewFileContent = "interface IFoo {\n  bar(): void;\n}\n\nclass Foo implements IFoo {\n  private x = 1;\n  constructor() { this.x = 2 }\n    bar(): void {\n        throw new Error(\"Method not implemented.\");\n    }\n}",
        .Index = 0,
    });
}

test "TestCompletionsAfterJSDoc" {
    const content =
        \\export interface Foo {
        \\  /** JSDoc */
        \\  /**/foo(): void;
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
//             .Exact = &.{
//                 &.{
//                     .Label =    "readonly",
//                     .Kind =     undefined(lsproto.CompletionItemKindKeyword),
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestReferencesInComment" {
    const content =
        \\// References to /*1*/foo or b/*2*/ar
        \\/* in comments should not find fo/*3*/o or bar/*4*/ */
        \\class foo { }
        \\var bar = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestGoToDefinitionExternalModuleName2" {
    const content =
        \\// @Filename: b.ts
        \\import n = require([|'./a/*1*/'|]);
        \\var x = new n.Foo();
        \\// @Filename: a.ts
        \\/*2*/class Foo {}
        \\export var x = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestIncrementalParsingDynamicImport4" {
    const content =
        \\// @lib: es2015
        \\// @Filename: ./foo.ts
        \\export function bar() { return 1; }
        \\// @Filename: ./0.ts
        \\/*1*/
        \\import { bar } from "./foo"
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyNumberOfErrorsInCurrentFile(undefined, 0);
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, "import");
    try f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
}

test "TestDocumentHighlights_33722" {
    const content =
        \\// @Filename: /y.ts
        \\class Foo {
        \\  private foo() {}
        \\}
        \\
        \\const f = () => new Foo();
        \\export default f;
        \\// @Filename: /x.ts
        \\import y from "./y";
        \\
        \\y().[|foo|]();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlightsWithOptions(undefined, null , &.{"/x.ts"}, f.Ranges()[0]);
}

test "TestCompletionListAtIdentifierDefinitionLocations_functions" {
    const content =
        \\var aa = 1;
        \\function /*functionName1*/
        \\function a/*functionName2*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, f.Markers(), null);
}

test "TestAutoImportPathsAliasesAndBarrels" {
    const content =
        \\// @Filename: /tsconfig.json
        \\ {
        \\  "compilerOptions": {
        \\    "module": "commonjs",
        \\    "paths": {
        \\      "~/*": ["src/*"]  
        \\    }
        \\  }
        \\}
        \\// @Filename: /src/dirA/index.ts
        \\ export * from "./thing1A";
        \\ export * from "./thing2A";
        \\// @Filename: /src/dirA/thing1A.ts
        \\ export class Thing1A {}
        \\ Thing/**/
        \\// @Filename: /src/dirA/thing2A.ts
        \\ export class Thing2A {}
        \\// @Filename: /src/dirB/index.ts
        \\ export * from "./thing1B";
        \\ export * from "./thing2B";
        \\// @Filename: /src/dirB/thing1B.ts
        \\ export class Thing1B {}
        \\// @Filename: /src/dirB/thing2B.ts
        \\ export class Thing2B {}
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
//                     .Label = "Thing2A",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./thing2A",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//                 &.{
//                     .Label = "Thing1B",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "~/dirB",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//                 &.{
//                     .Label = "Thing2B",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "~/dirB",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
}

test "TestImportNameCodeFix_importType" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: /a.js
        \\export {};
        \\/** @typedef {number} T */
        \\// @Filename: /b.js
        \\/** @type {T} */
        \\const x = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/b.js");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "/** @type {import(\"./a\").T} */\nconst x = 0;",
    }, null );
}

test "TestImportNameCodeFixDefaultExport2" {
    const content =
        \\// @Filename: /lib.ts
        \\class Base { }
        \\export default Base;
        \\// @Filename: /test.ts
        \\[|class Derived extends Base { }|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/test.ts");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import Base from \"./lib\";\n\nclass Derived extends Base { }",
    }, null );
}

test "TestCommentsImportDeclaration" {
    const content =
        \\// @Filename: commentsImportDeclaration_file0.ts
        \\/** NamespaceComment*/
        \\export namespace m/*2*/1 {
        \\    /** b's comment*/
        \\    export var b: number;
        \\    /** m2 comments*/
        \\    export namespace m2 {
        \\        /** class comment;*/
        \\        export class c {
        \\        };
        \\        /** i*/
        \\        export var i: c;;
        \\    }
        \\    /** exported function*/
        \\    export function fooExport(): number;
        \\}
        \\// @Filename: commentsImportDeclaration_file1.ts
        \\///<reference path='commentsImportDeclaration_file0.ts'/>
        \\/** Import declaration*/
        \\import /*3*/extMod = require("./commentsImportDeclaration_file0/*4*/");
        \\extMod./*6*/m1./*7*/fooEx/*8q*/port(/*8*/);
        \\var new/*9*/Var = new extMod.m1.m2./*10*/c();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "2", "namespace m1", "NamespaceComment");
    try f.VerifyQuickInfoAt(undefined, "3", "import extMod = require(\"./commentsImportDeclaration_file0\")", "Import declaration");
    // f.VerifyCompletions(undefined, "6", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =  "m1",
//                     .Detail = undefined("namespace extMod.m1"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "NamespaceComment",
//                         },
//                     },
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
//                     .Label =  "b",
//                     .Detail = undefined("var extMod.m1.b: number"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "b's comment",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "fooExport",
//                     .Detail = undefined("function extMod.m1.fooExport(): number"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "exported function",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "m2",
//                     .Detail = undefined("namespace extMod.m1.m2"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "m2 comments",
//                         },
//                     },
//                 },
//             },
//         },
//     });
    _ = f.GoToMarker(undefined, "8");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "exported function"});
    try f.VerifyQuickInfoAt(undefined, "8q", "function extMod.m1.fooExport(): number", "exported function");
    try f.VerifyQuickInfoAt(undefined, "9", "var newVar: extMod.m1.m2.c", "");
    // f.VerifyCompletions(undefined, "10", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =  "c",
//                     .Detail = undefined("constructor extMod.m1.m2.c(): extMod.m1.m2.c"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "class comment;",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "i",
//                     .Detail = undefined("var extMod.m1.m2.i: extMod.m1.m2.c"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "i",
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestCompletionAfterBackslashFollowingString" {
    const content =
        \\// @lib: es5
        \\Harness.newLine = ""\n/**/
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

test "TestCompletionListInScope_doesNotIncludeAugmentations" {
    const content =
        \\// @Filename: /a.ts
        \\import * as self from "./a";
        \\
        \\declare module "a" {
        \\    export const a: number;
        \\}
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
//             .Excludes = &.{
//                 "a",
//             },
//         },
//     });
}

test "TestJsdocDeprecated_suggestion18" {
    const content =
        \\// @jsx: preserve
        \\// @filename: foo.tsx
        \\interface Props {
        \\    /** @deprecated  */
        \\    x: number;
        \\    y: number;
        \\}
        \\function A(props: Props) {
        \\    return <div>{props.y}</div>
        \\}
        \\function B() {
        \\    return <A [|x|]={1} [|y|]={1} />
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifySuggestionDiagnostics(undefined, []*.{
//         .{
//             .Code =    &.{.Integer = undefined(int32(6385))},
//             .Message = .{.String = undefined("'x' is deprecated.")},
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//             .Range =   f.Ranges()[0].LSRange,
//         },
//     });
}

test "TestExportEqualNamespaceClassESModuleInterop" {
    const content =
        \\// @esModuleInterop: true
        \\// @moduleResolution: bundler
        \\// @target: es2015
        \\// @module: esnext
        \\// @Filename: /node_modules/@bar/foo/index.d.ts
        \\export = Foo;
        \\declare class Foo {}
        \\declare namespace Foo {}  // class/namespace declaration causes the issue
        \\// @Filename: /node_modules/foo/index.d.ts
        \\import * as Foo from "@bar/foo";
        \\export = Foo;
        \\// @Filename: /index.ts
        \\import Foo from "foo";
        \\/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/index.ts");
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "Foo",
//             },
//         },
//     });
}

test "TestCloduleTypeOf1" {
    const content =
        \\// @strict: false
        \\class C<T> {
        \\    static foo(x: number) { }
        \\    x: T;
        \\}
        \\
        \\namespace C {
        \\    export function f(x: typeof C) {
        \\        x./*1*/
        \\        var /*3*/r = new /*2*/x<number>();
        \\        var /*5*/r2 = r./*4*/
        \\        return typeof r;
        \\    }
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
//                     .Label =    "f",
//                     .SortText = undefined(string(ls.SortTextLocationPriority)),
//                 },
//                 &.{
//                     .Label =    "foo",
//                     .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                 },
//             },
//         },
//     });
    _ = f.Insert(undefined, "foo(1);");
    // f.VerifyCompletions(undefined, "2", &.{
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
    try f.VerifyQuickInfoAt(undefined, "3", "(local var) r: C<number>", "");
    // f.VerifyCompletions(undefined, "4", &.{
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
    _ = f.Insert(undefined, "x;");
    try f.VerifyQuickInfoAt(undefined, "5", "(local var) r2: number", "");
    try f.VerifyNoErrors(undefined);
}

test "TestRenameNumericalIndex" {
    const content =
        \\const foo = { [|0|]: true };
        \\foo[[|0|]];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null , "0");
}

test "TestGoToImplementationInterfaceMethod_06" {
    const content =
        \\interface SuperFoo {
        \\    hello (): void;
        \\}
        \\
        \\interface Foo extends SuperFoo {
        \\    someOtherFunction(): void;
        \\}
        \\
        \\class Bar implements Foo {
        \\     [|hello|]() {}
        \\     someOtherFunction() {}
        \\}
        \\
        \\function createFoo(): Foo {
        \\    return {
        \\        [|hello|]() {},
        \\        someOtherFunction() {}
        \\    };
        \\}
        \\
        \\var y: Foo = {
        \\    [|hello|]() {},
        \\    someOtherFunction() {}
        \\};
        \\
        \\class FooLike implements SuperFoo {
        \\     hello() {}
        \\     someOtherFunction() {}
        \\}
        \\
        \\class NotRelatedToFoo {
        \\     hello() {}                // This case is equivalent to the last case, but is not returned because it does not share a common ancestor with Foo
        \\     someOtherFunction() {}
        \\}
        \\
        \\class NotFoo implements SuperFoo {
        \\     hello() {}                // We only want implementations of Foo, even though the function is declared in SuperFoo
        \\}
        \\
        \\function (x: Foo) {
        \\    x.he/*function_call*/llo()
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "function_call");
}

test "TestImportNameCodeFixNewImportNodeModules8" {
    const content =
        \\[|f1/*0*/('');|]
        \\// @Filename: package.json
        \\{ "dependencies": { "@scope/package-name": "latest" } }
        \\// @Filename: node_modules/@scope/package-name/bin/lib/index.d.ts
        \\export function f1(text: string): string;
        \\// @Filename: node_modules/@scope/package-name/bin/lib/index.js
        \\function f1(text) { }
        \\exports.f1 = f1;
        \\// @Filename: node_modules/@scope/package-name/package.json
        \\{
        \\  "main": "bin/lib/index.js",
        \\  "types": "bin/lib/index.d.ts"
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { f1 } from \"@scope/package-name\";\n\nf1('');",
    }, null );
}

test "TestSmartSelection_JSDocTags1" {
    const content =
        \\/**
        \\ * @returns {Array<{ value: /**/string }>}
        \\ */
        \\function foo() { return [] }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSelectionRanges(undefined);
}

test "TestGoToDefinitionAwait2" {
    const content =
        \\[|/*start*/await|] Promise.resolve(0);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "start");
}

test "TestUnderscoreTypings01" {
    const content =
        \\interface Iterator_<T, U> {
        \\    (value: T, index: any, list: any): U;
        \\}
        \\
        \\interface WrappedArray<T> {
        \\    map<U>(iterator: Iterator_<T, U>, context?: any): U[];
        \\}
        \\
        \\interface Underscore {
        \\    <T>(list: T[]): WrappedArray<T>;
        \\    map<T, U>(list: T[], iterator: Iterator_<T, U>, context?: any): U[];
        \\}
        \\
        \\declare var _: Underscore;
        \\
        \\var a: string[];
        \\var /*1*/b = _.map(a, /*2*/x => x.length);    // Was typed any[], should be number[]
        \\var /*3*/c = _(a).map(/*4*/x => x.length);
        \\var /*5*/d = a.map(/*6*/x => x.length);
        \\
        \\var aa: any[];
        \\var /*7*/bb = _.map(aa, /*8*/x => x.length);
        \\var /*9*/cc = _(aa).map(/*10*/x => x.length);
        \\var /*11*/dd = aa.map(/*12*/x => x.length);
        \\
        \\var e = a.map(x => x./*13*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "var b: number[]", "");
    try f.VerifyQuickInfoAt(undefined, "2", "(parameter) x: string", "");
    try f.VerifyQuickInfoAt(undefined, "3", "var c: number[]", "");
    try f.VerifyQuickInfoAt(undefined, "4", "(parameter) x: string", "");
    try f.VerifyQuickInfoAt(undefined, "5", "var d: number[]", "");
    try f.VerifyQuickInfoAt(undefined, "6", "(parameter) x: string", "");
    try f.VerifyQuickInfoAt(undefined, "7", "var bb: any[]", "");
    try f.VerifyQuickInfoAt(undefined, "8", "(parameter) x: any", "");
    try f.VerifyQuickInfoAt(undefined, "9", "var cc: any[]", "");
    try f.VerifyQuickInfoAt(undefined, "10", "(parameter) x: any", "");
    try f.VerifyQuickInfoAt(undefined, "11", "var dd: any[]", "");
    try f.VerifyQuickInfoAt(undefined, "12", "(parameter) x: any", "");
    // f.VerifyCompletions(undefined, "13", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "length",
//             },
//             .Excludes = &.{
//                 "toFixed",
//             },
//         },
//     });
}

test "TestFindAllRefsWithLeadingUnderscoreNames7" {
    const content =
        \\/*1*/function /*2*/__foo() {
        \\    /*3*/__foo();
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestFindAllRefsParameterPropertyDeclaration1" {
    const content =
        \\class Foo {
        \\    constructor(private /*1*/privateParam: number) {
        \\        let localPrivate = privateParam;
        \\        this.privateParam += 10;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestInlayHintsInteractiveVariableTypes1" {
    const content =
        \\class C {}
        \\namespace N { export class Foo {} }
        \\interface Foo {}
        \\const a = "a";
        \\const b = 1;
        \\const c = true;
        \\const d = {} as Foo;
        \\const e = <Foo>{};
        \\const f = {} as const;
        \\const g = (({} as const));
        \\const h = new C();
        \\const i = new N.C();
        \\const j = ((((new C()))));
        \\const k = { a: 1, b: 1 };
        \\const l = ((({ a: 1, b: 1 })));
        \\ const m = () => 123;
        \\ const n;
        \\ const o = () => -1 as const;
        \\ const p = ([a]: Foo[]) => a;
        \\ const q = ({ a }: { a: Foo }) => a;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayVariableTypeHints = core.TSTrue}});
}

test "TestMemberListOfModuleAfterInvalidCharater" {
    const content =
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
//                 &.{
//                     .Label =  "foo",
//                     .Detail = undefined("var testModule.foo: number"),
//                 },
//             },
//         },
//     });
}

test "TestNavigationBarItemsClass3" {
    const content =
        \\// @allowJs: true
        \\// @filename: /foo.js
        \\function Foo() {}
        \\class Foo {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestModuleNodeNextAutoImport3" {
    const content =
        \\// @Filename: /tsconfig.json
        \\{ "compilerOptions": { "module": "nodenext" } }
        \\// @Filename: /package.json
        \\{ "type": "module" }
        \\// @Filename: /mobx.d.mts
        \\export declare function autorun(): void;
        \\// @Filename: /index.ts
        \\autorun/**/
        \\// @Filename: /utils.ts
        \\import "./mobx.mjs";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { autorun } from \"./mobx.mjs\";\n\nautorun",
    }, null );
}

test "TestGetOccurrencesSwitchCaseDefault" {
    const content =
        \\[|switch|] (10) {
        \\    [|case|] 1:
        \\    [|case|] 2:
        \\    [|case|] 4:
        \\    [|case|] 8:
        \\        foo: switch (20) {
        \\            case 1:
        \\            case 2:
        \\                break;
        \\            default:
        \\                break foo;
        \\        }
        \\    [|case|] 0xBEEF:
        \\    [|default|]:
        \\        [|break|];
        \\    [|case|] 16:
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestRenameNameOnEnumMember" {
    const content =
        \\enum e {
        \\    firstMember,
        \\    secondMember,
        \\    thirdMember
        \\}
        \\var enumMember = e.[|/**/thirdMember|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyRenameSucceeded(undefined, null );
}

test "TestFormatControlFlowConstructs" {
    const content =
        \\if (true)/**/
        \\{     
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "");
    try f.VerifyCurrentLineContent(undefined, "if (true) {");
}

test "TestAutoImportProvider7" {
    const content =
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{ "compilerOptions": { "lib": ["es5"], "module": "commonjs" } }
        \\// @Filename: /home/src/workspaces/project/package.json
        \\{ "dependencies": { "mylib": "file:packages/mylib" } }
        \\// @Filename: /home/src/workspaces/project/packages/mylib/package.json
        \\{ "name": "mylib", "version": "1.0.0", "main": "index.js", "types": "index" }
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
    // f.Configure(undefined, opts1196);
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
//                             .ModuleSpecifier = "mylib",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
    // try f.VerifyApplyCodeActionFromCompletion(undefined, undefined("1"), &.{
//         .Name =          "MyClass",
//         .Source =        "mylib",
//         .Description =   "Add import from \"mylib\"",
//         .AutoImportFix = &.{},
//         .NewFileContent = undefined("import { MyClass } from \"mylib\";\n\nconst a = new MyClass();\nconst b = new MyClass2();"),
//     });
}

test "TestInterfaceExtendsPrimitive" {
    const content =
        \\interface x extends /*1*/string/*2*/ { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyErrorExistsBetweenMarkers(undefined, "1", "2");
    try f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
}

test "TestTypeReferenceAndImportDeprecated" {
    const content =
        \\// @filename: types.ts
        \\/** @deprecated */
        \\export type SelectorMap<T extends Record<string, (...params: unknown[]) => unknown>> = {
        \\    [key in keyof T]: T[key];
        \\};
        \\// @filename: index.ts
        \\/** @deprecated */
        \\export type SelectorMap<T extends Record<string, (...params: unknown[]) => unknown>> = {
        \\    [key in keyof T]: T[key];
        \\};
        \\
        \\export declare const value2: {
        \\    sliceSelectors: <FuncMap extends [|import('./types').SelectorMap<FuncMap>|]>(selectorsBySlice: FuncMap) => { [P in keyof FuncMap]: Parameters<FuncMap[P]> };
        \\};
        \\
        \\export declare const value3: {
        \\    sliceSelectors: <FuncMap extends [|SelectorMap<FuncMap>|]>(selectorsBySlice: FuncMap) => { [P in keyof FuncMap]: Parameters<FuncMap[P]> };
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "index.ts");
    // try f.VerifySuggestionDiagnostics(undefined, []*.{
//         .{
//             .Code =    &.{.Integer = undefined(int32(6385))},
//             .Message = .{.String = undefined("'SelectorMap' is deprecated.")},
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//             .Range =   f.Ranges()[0].LSRange,
//         },
//         .{
//             .Code =    &.{.Integer = undefined(int32(6385))},
//             .Message = .{.String = undefined("'SelectorMap' is deprecated.")},
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//             .Range =   f.Ranges()[1].LSRange,
//         },
//     });
}

test "TestCompletionListInTypeLiteralInTypeParameter15" {
    const content =
        \\interface Foo {
        \\   one: string;
        \\   two: number;
        \\}
        \\
        \\declare function decorator<T extends Foo>(originalMethod: unknown, _context: unknown): never
        \\
        \\class {
        \\   @decorator<{/*0*/}>
        \\   method() {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "0", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
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

test "TestJsDocFunctionTypeCompletionsNoCrash" {
    const content =
        \\// @lib: es5
        \\/**
        \\ * @returns {function/**/(): string}
        \\ */
        \\function updateCalendarEvent() {
        \\  return "";
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
//             .Exact = CompletionGlobalTypes,
//         },
//     });
}

test "TestTsxCompletionOnClosingTagWithoutJSX1" {
    const content =
        \\//@Filename: file.tsx
        \\var x1 = <div><//**/
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
//                 "div>",
//             },
//         },
//     });
}

test "TestCompletionListOutsideOfForLoop02" {
    const content =
        \\for (let i = 0; i < 10; i++);/*1*/
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
//                 "i",
//             },
//         },
//     });
}

test "TestJsDocPropertyDescription1" {
    const content =
        \\interface StringExample {
        \\    /** Something generic */
        \\    [p: string]: any; 
        \\    /** Something specific */
        \\    property: number;
        \\}
        \\function stringExample(e: StringExample) {
        \\    console.log(e./*property*/property);
        \\    console.log(e./*string*/anything); 
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "property", "(property) StringExample.property: number", "Something specific");
    try f.VerifyQuickInfoAt(undefined, "string", "(index) StringExample[string]: any", "Something generic");
}

test "TestMemberConstructorEdits" {
    const content =
        \\ namespace M {
        \\     export class A {
        \\         constructor(a: string) {}
        \\         public m(n: number) {
        \\             return 0;
        \\         }
        \\         public n() {
        \\             return this.m(0);
        \\         }
        \\     }
        \\     export class B extends A {
        \\         constructor(a: string) {
        \\            super(a);
        \\        }
        \\        /*1*/
        \\     }
        \\     var a = new A("s");
        \\     var b = new B("s");
        \\ }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyNoErrors(undefined);
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, "public m(n: number) { return 0; }");
    try f.VerifyNoErrors(undefined);
}

test "TestGoToDefinitionImportedNames" {
    const content =
        \\// @Filename: b.ts
        \\export {[|/*classAliasDefinition*/Class|]} from "./a";
        \\// @Filename: a.ts
        \\export namespace Module {
        \\}
        \\export class /*classDefinition*/Class {
        \\    private f;
        \\}
        \\export interface Interface {
        \\    x;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "classAliasDefinition");
}

test "TestFindAllRefsInheritedProperties3" {
    const content =
        \\class class1 extends class1 {
        \\    [|/*0*/doStuff() { }|]
        \\    [|/*1*/propName: string;|]
        \\}
        \\interface interface1 extends interface1 {
        \\    [|/*2*/doStuff(): void;|]
        \\    [|/*3*/propName: string;|]
        \\}
        \\class class2 extends class1 implements interface1 {
        \\    [|/*4*/doStuff() { }|]
        \\    [|/*5*/propName: string;|]
        \\}
        \\
        \\var v: class2;
        \\v./*6*/doStuff();
        \\v./*7*/propName;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "0", "1", "2", "3", "4", "6", "5", "7");
}

test "TestGoToImplementationInterfaceProperty_00" {
    const content =
        \\interface Foo {
        \\    hello: number
        \\}
        \\
        \\var bar: Foo = { [|hello|]: 5 };
        \\
        \\
        \\function whatever(x: Foo = { [|hello|]: 5 * 9 }) {
        \\    x.he/*reference*/llo
        \\}
        \\
        \\class Bar {
        \\    x: Foo = { [|hello|]: 6 }
        \\
        \\    constructor(public f: Foo = { [|hello|]: 7 } ) {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "reference");
}

test "TestCompletionsForLatterTypeParametersInConstraints1" {
    const content =
        \\// https://github.com/microsoft/TypeScript/issues/56474
        \\function test<First extends S/*1*/, Second>(a: First, b: Second) {}
        \\type A1<K extends /*2*/, L> = K
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
//             .Includes = &.{
//                 "Second",
//             },
//             .Excludes = &.{
//                 "First",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"2"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "L",
//             },
//             .Excludes = &.{
//                 "K",
//             },
//         },
//     });
}

test "TestFormattingSingleLineWithNewLineOptionSet" {
    const content =
        \\/*1*/namespace Default{}
        \\/*2*/function foo(){}
        \\/*3*/if (true){}
        \\/*4*/function boo() {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.GetOptions();
    // f.Configure(undefined, opts211);
    // f.GetOptions();
    // f.Configure(undefined, opts279);
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCurrentLineContent(undefined, "namespace Default { }");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyCurrentLineContent(undefined, "function foo() { }");
    _ = f.GoToMarker(undefined, "3");
    try f.VerifyCurrentLineContent(undefined, "if (true) { }");
    _ = f.GoToMarker(undefined, "4");
    try f.VerifyCurrentLineContent(undefined, "function boo()");
}

test "TestCompletionListForTransitivelyExportedMembers02" {
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
        \\var x = c.Inner./**/
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
//                 "constVar",
//                 "letVar",
//                 "varVar",
//             },
//         },
//     });
}

test "TestFindAllRefsJsDocTypeDef" {
    const content =
        \\/** @typedef {Object} /*0*/T */
        \\function foo() {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "0");
}

test "TestVerifySingleFileEmitOutput1" {
    const content =
        \\// @Filename: verifySingleFileEmitOutput1_file0.ts
        \\export class A {
        \\}
        \\export class Z {
        \\}
        \\// @Filename: verifySingleFileEmitOutput1_file1.ts
        \\import f = require("./verifySingleFileEmitOutput1_file0");
        \\var /**/b = new f.A();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "var b: f.A", "");
}

test "TestQuickInfoJsDocTags10" {
    const content =
        \\// @noEmit: true
        \\// @allowJs: true
        \\// @Filename: quickInfoJsDocTags10.js
        \\/**
        \\ * @param {T1} a
        \\ * @param {T2} a
        \\ * @template T1,T2 Comment Text
        \\ */
        \\const /**/foo = (a, b) => {};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestCodeFixClassImplementInterfaceTypeParamInstantiateNumber" {
    const content =
        \\interface I<T> { x: T; }
        \\class C implements I<number> { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'I<number>'",
        .NewFileContent = "interface I<T> { x: T; }\nclass C implements I<number> {\n    x: number;\n}",
        .Index = 0,
    });
}

test "TestAutoImportSpecifierExcludeRegexes1" {
    const content =
        \\// @module: preserve
        \\// @Filename: /node_modules/lib/index.d.ts
        \\declare module "ambient" {
        \\    export const x: number;
        \\}
        \\declare module "ambient/utils" {
        \\   export const x: number;
        \\}
        \\// @Filename: /index.ts
        \\x/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"ambient", "ambient/utils"}, null );
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"ambient"}, &.{.AutoImportSpecifierExcludeRegexes = &.{"utils"}});
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"ambient", "ambient/utils"}, &.{.AutoImportSpecifierExcludeRegexes = &.{"/UTILS/"}});
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"ambient"}, &.{.AutoImportSpecifierExcludeRegexes = &.{"/UTILS/i"}});
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"ambient", "ambient/utils"}, &.{.AutoImportSpecifierExcludeRegexes = &.{"/ambient/utils/"}});
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"ambient"}, &.{.AutoImportSpecifierExcludeRegexes = &.{"/ambient\\/utils/"}});
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"ambient"}, &.{.AutoImportSpecifierExcludeRegexes = &.{"/.*?$"}});
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"ambient"}, &.{.AutoImportSpecifierExcludeRegexes = &.{"^ambient/"}});
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"ambient/utils"}, &.{.AutoImportSpecifierExcludeRegexes = &.{"ambient$"}});
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"ambient", "ambient/utils"}, &.{.AutoImportSpecifierExcludeRegexes = &.{"oops("}});
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
//                             .ModuleSpecifier = "ambient",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//                 &.{
//                     .Label = "x",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "ambient/utils",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
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
//             .Excludes = &.{
//                 "ambient/utils",
//             },
//         },
//         .UserPreferences = &.{.AutoImportSpecifierExcludeRegexes = &.{"utils"}},
//     });
}

test "TestReferencesForExternalModuleNames" {
    const content =
        \\// @Filename: referencesForGlobals_1.ts
        \\/*1*/declare module "/*2*/foo" {
        \\    var f: number;
        \\}
        \\// @Filename: referencesForGlobals_2.ts
        \\/*3*/import f = require("/*4*/foo");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestCompletionListForTransitivelyExportedMembers04" {
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
        \\var x: c.Inner./**/
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
//                 "I3",
//             },
//         },
//     });
}

test "TestSignatureHelpInCompleteGenericsCall" {
    const content =
        \\function foo<T>(x: number, callback: (x: T) => number) {
        \\}
        \\foo(/*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // try f.VerifySignatureHelp(undefined, .{.Text = "foo(x: number, callback: (x: unknown) => number): void"});
}

test "TestUnusedImports3FS" {
    const content =
        \\// @noUnusedLocals: true
        \\// @Filename: file2.ts
        \\[| import {Calculator, /*some comments*/ test, test2} from "./file1" |]
        \\ test();
        \\ test2();
        \\// @Filename: file1.ts
        \\ export class Calculator {
        \\     handleChar() {}
        \\ }
        \\ export function test() {
        \\
        \\ }
        \\ export function test2() {
        \\
        \\ }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyRangeAfterCodeFix(undefined, "import {/*some comments*/ test, test2} from \"./file1\"", false, 0, 0);
}

test "TestGetOutliningForArrayDestructuring" {
    const content =
        \\const[| [
        \\    a,
        \\    b,
        \\    c
        \\]|] =[| [
        \\    1,
        \\    2,
        \\    3
        \\]|];
        \\const[| [
        \\    [|[
        \\        [|[
        \\            [|[
        \\                a,
        \\                b,
        \\                c
        \\            ]|]
        \\        ]|]
        \\    ]|],
        \\    [|[
        \\        a1,
        \\        b1,
        \\        c1
        \\    ]|]
        \\]|] =[| [
        \\    [|[
        \\        [|[
        \\            [|[
        \\                1,
        \\                2,
        \\                3
        \\            ]|]
        \\        ]|]
        \\    ]|],
        \\    [|[
        \\        1,
        \\        2,
        \\        3
        \\    ]|]
        \\]|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyOutliningSpans(undefined);
}

test "TestGotoDefinitionInObjectBindingPattern2" {
    const content =
        \\var p0 = ({a/*1*/a}) => {console.log(aa)};
        \\function f2({ [|a/*a1*/1|], [|b/*b1*/1|] }: { /*a1_dest*/a1: number, /*b1_dest*/b1: number } = { a1: 0, b1: 0 }) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "1", "a1", "b1");
}

test "TestSignatureHelpInFunctionCallOnFunctionDeclarationInMultipleFiles" {
    const content =
        \\// @Filename: signatureHelpInFunctionCallOnFunctionDeclarationInMultipleFiles_file0.ts
        \\declare function fn(x: string, y: number);
        \\// @Filename: signatureHelpInFunctionCallOnFunctionDeclarationInMultipleFiles_file1.ts
        \\declare function fn(x: string);
        \\// @Filename: signatureHelpInFunctionCallOnFunctionDeclarationInMultipleFiles_file2.ts
        \\fn(/*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // try f.VerifySignatureHelp(undefined, .{.OverloadsCount = 2});
}

test "TestFindAllRefsForDefaultKeyword" {
    const content =
        \\// @noLib: true
        \\function f(value: string, /*1*/default: string) {}
        \\
        \\const /*2*/default = 1;
        \\
        \\function /*3*/default() {}
        \\
        \\class /*4*/default {}
        \\
        \\const foo = {
        \\    /*5*/default: 1
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5");
}

test "TestCompletionListInUnclosedCommaExpression01" {
    const content =
        \\// should NOT see a and b
        \\foo((a, b) => a,/*1*/
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
//             .Excludes = &.{
//                 "a",
//                 "b",
//             },
//         },
//     });
}

