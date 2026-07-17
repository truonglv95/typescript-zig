const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestTsxCompletionOnClosingTag2" {
    const content =
        \\//@Filename: file.tsx
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\        div: { ONE: string; TWO: number; }
        \\    }
        \\}
        \\var x1 = <div>
        \\   <h1> Hello world </ /*2*/>
        \\   </ /*1*/>
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
//                 "div",
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
//                 "h1",
//             },
//         },
//     });
}

test "TestRenameRestBindingElement" {
    const content =
        \\interface I {
        \\    a: number;
        \\    b: number;
        \\    c: number;
        \\}
        \\function foo([|{ a, ...[|{| "contextRangeIndex": 0 |}rest|] }: I|]) {
        \\    [|rest|];
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, &.{.UseAliasesForRename = core.TSTrue}, f.Ranges()[1]);
}

test "TestFindAllRefs_importType_js3" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: /a.js
        \\module.exports = class C {};
        \\module.exports.D = class /**/D {};
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

test "TestIncrementalResolveConstructorDeclaration" {
    const content =
        \\class c1 {
        \\    private b: number;
        \\    constructor(a: string) {
        \\        this.b = a;
        \\    }
        \\}
        \\var val = new c1("hello");
        \\/*1*/val;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "var val: c1", "");
    try f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
}

test "TestIsDefinitionOverloads" {
    const content =
        \\function /*1*/f(x: number): void;
        \\function /*2*/f(x: string): void;
        \\function /*3*/f(x: number | string) { }
        \\
        \\f(1);
        \\f("a");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestQuickInfoLink8" {
    const content =
        \\const A = 123;
        \\/**
        \\ * See {@link A | constant A} instead
        \\ */
        \\const /**/B = 456;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestJsDocSee4" {
    const content =
        \\class [|/*def1*/A|] {
        \\    foo () { }
        \\}
        \\declare const [|/*def2*/a|]: A;
        \\/**
        \\ * @see {/*use1*/[|A|]#foo}
        \\ */
        \\const t1 = 1
        \\/**
        \\ * @see {/*use2*/[|a|].foo()}
        \\ */
        \\const t2 = 1
        \\/**
        \\ * @see {@link /*use3*/[|a|].foo()}
        \\ */
        \\const t3 = 1
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, false, "use1", "use2", "use3");
}

test "TestAutoImportPnpm" {
    const content =
        \\// @Filename: /tsconfig.json
        \\{ "compilerOptions": { "module": "commonjs" } }
        \\// @Filename: /node_modules/.pnpm/mobx@6.0.4/node_modules/mobx/package.json
        \\{ "types": "dist/mobx.d.ts" }
        \\// @Filename: /node_modules/.pnpm/mobx@6.0.4/node_modules/mobx/dist/mobx.d.ts
        \\export declare function autorun(): void;
        \\// @Filename: /index.ts
        \\autorun/**/
        \\// @Filename: /utils.ts
        \\import "mobx";
        \\// @link: /node_modules/.pnpm/mobx@6.0.4/node_modules/mobx -> /node_modules/mobx
        \\// @link: /node_modules/.pnpm/mobx@6.0.4/node_modules/mobx -> /node_modules/.pnpm/cool-mobx-dependent@1.2.3/node_modules/mobx
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { autorun } from \"mobx\";\n\nautorun",
    }, null );
}

test "TestAutoImportProvider_importsMap2" {
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
        \\    "#internal/*": "./dist/internal/*"
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/src/internal/foo.ts
        \\export function something(name: string) {}
        \\// @Filename: /home/src/workspaces/project/src/a.ts
        \\something/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"#internal/foo.js"}, null );
}

test "TestCompletionListInExtendsClauseAtEOF" {
    const content =
        \\declare namespace mod {
        \\    class Foo { }
        \\}
        \\class Bar extends mod./**/
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
//                 "Foo",
//             },
//         },
//     });
}

test "TestCompletionsWithOptionalPropertiesGenericConstructor" {
    const content =
        \\// @strict: true
        \\interface Options {
        \\    someFunction?: () => string
        \\    anotherFunction?: () => string
        \\}
        \\
        \\export class Clazz<T extends Options> {
        \\    constructor(public a: T) {}
        \\}
        \\
        \\new Clazz({ /*1*/ })
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
//                     .Label =      "someFunction?",
//                     .InsertText = undefined("someFunction"),
//                     .FilterText = undefined("someFunction"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//                 &.{
//                     .Label =      "anotherFunction?",
//                     .InsertText = undefined("anotherFunction"),
//                     .FilterText = undefined("anotherFunction"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//             },
//         },
//     });
}

test "TestConstructorFindAllReferences1" {
    const content =
        \\export class C {
        \\    /**/public constructor() { }
        \\    public foo() { }
        \\}
        \\
        \\new C().foo();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "");
}

test "TestCompletionListInUnclosedFunction01" {
    const content =
        \\function foo(x: string, y: number, z: boolean) {
        \\    /*1*/
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
//             },
//         },
//     });
}

test "TestJsDocTagsWithHyphen" {
    const content =
        \\// @allowJs: true
        \\// @Filename: dummy.js
        \\/**
        \\ * @typedef Product
        \\ * @property {string} title
        \\ * @property {boolean} h/*1*/igh-top some-comments
        \\ */
        \\
        \\/**
        \\ * @type {Pro/*2*/duct}
        \\ */
        \\const product = {
        \\    /*3*/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "(property) high-top: boolean", "some-comments");
    try f.VerifyQuickInfoAt(undefined, "2", "type Product = {\n    title: string;\n    \"high-top\": boolean;\n}", "");
    // f.VerifyCompletions(undefined, &.{"3"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "\"high-top\"",
//             },
//         },
//     });
}

test "TestGoToDefinitionImportedNames3" {
    const content =
        \\// @Filename: e.ts
        \\ import {M, [|/*classAliasDefinition*/C|], I} from "./d";
        \\ var c = new [|/*classReference*/C|]();
        \\// @Filename: d.ts
        \\export * from "./c";
        \\// @Filename: c.ts
        \\export {Module as M, Class as C, Interface as I} from "./b";
        \\// @Filename: b.ts
        \\export * from "./a";
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
    // try f.VerifyBaselineGoToDefinition(undefined, true, "classReference", "classAliasDefinition");
}

test "TestRenameImportRequire" {
    const content =
        \\// @Filename: /a.ts
        \\[|import [|{| "contextRangeIndex": 0 |}e|] = require("mod4");|]
        \\[|e|];
        \\a = { [|e|] };
        \\[|export { [|{| "contextRangeIndex": 4 |}e|] };|]
        \\// @Filename: /b.ts
        \\[|import { [|{| "contextRangeIndex": 6 |}e|] } from "./a";|]
        \\[|export { [|{| "contextRangeIndex": 8 |}e|] };|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[1], f.Ranges()[2], f.Ranges()[3], f.Ranges()[5], f.Ranges()[7], f.Ranges()[9]);
}

test "TestFormatTryCatch" {
    const content =
        \\function test() {
        \\    /*try*/try {
        \\    }
        \\    /*catch*/catch (e) {
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.FormatDocument(undefined, "");
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "try");
    try f.VerifyCurrentLineContent(undefined, "    try {");
    _ = f.GoToMarker(undefined, "catch");
    try f.VerifyCurrentLineContent(undefined, "    catch (e) {");
}

test "TestCodeFixAwaitInSyncFunction4" {
    const content =
        \\class Foo {
        \\    constructor {
        \\        await Promise.resolve();
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined);
}

test "TestImportNameCodeFix_all_js" {
    const content =
        \\// @module: esnext
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: /a.js
        \\export class C {}
        \\/** @typedef {number} T */
        \\// @Filename: /b.js
        \\C;
        \\/** @type {T} */
        \\const x = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/b.js");
    try f.VerifyCodeFixAll(undefined, .{
        .FixID = "fixMissingImport",
        .NewFileContent = "import { C } from \"./a\";\n\nC;\n/** @type {import(\"./a\").T} */\nconst x = 0;",
    });
}

test "TestSignatureHelpOptionalCall2" {
    const content =
        \\// @strict: false
        \\declare const fnTest: undefined | ((str: string, num: number) => void);
        \\fnTest?.(/*1*/);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // try f.VerifySignatureHelp(undefined, .{.Text = "fnTest(str: string, num: number): void", .ParameterCount = 2, .ParameterName = "str", .ParameterSpan = "str: string"});
}

test "TestConsistentContextualTypeErrorsAfterEdits" {
    const content =
        \\// @strict: false
        \\class A {
        \\    foo: string;
        \\}
        \\class C {
        \\    foo: string;
        \\}
        \\var xs /*1*/ = [(x: A) => { return x.foo; }, (x: C) => { return x.foo; }];
        \\xs.forEach(y => y(new /*2*/A()));
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyNumberOfErrorsInCurrentFile(undefined, 0);
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, ": {}[]");
    try f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
    _ = f.GoToMarker(undefined, "2");
    _ = f.DeleteAtCaret(undefined, 1);
    _ = f.Insert(undefined, "C");
    try f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
}

test "TestJsdocOverloadTagCompletion" {
    const content =
        \\// @allowJS: true
        \\// @checkJs: true
        \\// @filename: /a.js
        \\/**
        \\ * @/**/
        \\ */
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
//                 "overload",
//             },
//         },
//     });
}

test "TestCompletionForStringLiteralNonrelativeImportTypings2" {
    const content =
        \\// @typeRoots: my_typings,my_other_typings
        \\// @types: module-x,module-z
        \\// @Filename: tests/test0.ts
        \\/// <reference types="m/*types_ref0*/" />
        \\import * as foo1 from "m/*import_as0*/
        \\import foo2 = require("m/*import_equals0*/
        \\var foo3 = require("m/*require0*/
        \\// @Filename: my_typings/module-x/index.d.ts
        \\export var x = 9;
        \\// @Filename: my_typings/module-y/index.d.ts
        \\export var y = 9;
        \\// @Filename: my_other_typings/module-z/index.d.ts
        \\export var z = 9;
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
//                 "module-x",
//                 "module-z",
//             },
//         },
//     });
}

test "TestCompletionListInUnclosedObjectTypeLiteralInSignature04" {
    const content =
        \\interface I<TString, TNumber> {
        \\    [s: string]: TString;
        \\    [s: number]: TNumber;
        \\}
        \\
        \\declare function foo<TString, TNumber>(obj: I<TString, TNumber>): { /*1*/
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

test "TestGetJavaScriptCompletions20" {
    const content =
        \\// @lib: es5
        \\// @allowNonTsExtensions: true
        \\// @Filename: file.js
        \\/**
        \\ * A person
        \\ * @constructor
        \\ * @param {string} name - The name of the person.
        \\ * @param {number} age - The age of the person.
        \\ */
        \\function Person(name, age) {
        \\    this.name = name;
        \\    this.age = age;
        \\}
        \\
        \\
        \\Person.getName = 10;
        \\Person.getNa/**/ = 10;
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
//             .Exact = CompletionFunctionMembersWithPrototypePlus(
//                 &.{
//                     "getName",
//                     "getNa",
//                     &.{
//                         .Label =    "Person",
//                         .SortText = undefined(string(ls.SortTextJavascriptIdentifiers)),
//                     },
//                     &.{
//                         .Label =    "name",
//                         .SortText = undefined(string(ls.SortTextJavascriptIdentifiers)),
//                     },
//                     &.{
//                         .Label =    "age",
//                         .SortText = undefined(string(ls.SortTextJavascriptIdentifiers)),
//                     },
//                 },
//             ),
//         },
//     });
}

test "TestCompletionsGenericIndexedAccess6" {
    const content =
        \\// @Filename: component.tsx
        \\interface CustomElements {
        \\  'component-one': {
        \\      foo?: string;
        \\  },
        \\  'component-two': {
        \\      bar?: string;
        \\  }
        \\}
        \\
        \\type Options<T extends keyof CustomElements> = { kind: T } & Required<{ x: CustomElements[(T extends string ? T : never) & string] }['x']>;
        \\
        \\declare function Component<T extends keyof CustomElements>(props: Options<T>): void;
        \\
        \\const c = <Component /**/ kind="component-one" />
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
//                 },
//             },
//         },
//     });
}

test "TestGetQuickInfoForIntersectionTypes" {
    const content =
        \\function f(): string & {(): any} {
        \\    return <any>{};
        \\}
        \\let x = f();
        \\x/**/();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "let x: () => any", "");
}

test "TestCodeFixAddMissingFunctionDeclaration16" {
    const content =
        \\// @moduleResolution: bundler
        \\// @filename: /node_modules/test/index.js
        \\export const x = 1;
        \\// @filename: /foo.ts
        \\import * as test from "test";
        \\test.foo();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/foo.ts");
    // try f.VerifyCodeFixNotAvailable(undefined);
}

test "TestMemberListOfVarInArrowExpression" {
    const content =
        \\interface IMap<T> {
        \\    [key: string]: T;
        \\}
        \\var map: IMap<{ a1: string; }[]>;
        \\var categories: string[];
        \\each(categories, category => {
        \\    var changes = map[category];
        \\    changes[0]./*1*/a1;
        \\    return each(changes, change => {
        \\    });
        \\});
        \\function each<T>(items: T[], handler: (item: T) => void) { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "(property) a1: string", "");
    // f.VerifyCompletions(undefined, "1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =  "a1",
//                     .Detail = undefined("(property) a1: string"),
//                 },
//             },
//         },
//     });
}

test "TestGoToDefinitionRest" {
    const content =
        \\interface Gen {
        \\    x: number;
        \\    /*1*/parent: Gen;
        \\    millenial: string;
        \\}
        \\let t: Gen;
        \\var { x, ...rest } = t;
        \\rest.[|/*2*/parent|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "2");
}

test "TestInlayHintsVariableTypes3" {
    const content =
        \\// @strict: true
        \\// @target: esnext
        \\interface DivElement {}
        \\declare var DivElementCtor: {
        \\  prototype: DivElement;
        \\  new(): DivElement;
        \\};
        \\interface ElementMap {
        \\  div: typeof DivElementCtor;
        \\}
        \\declare function getCtor<K extends keyof ElementMap>(tagName: K): ElementMap[K] | undefined;
        \\const div = getCtor("div");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayVariableTypeHints = core.TSTrue}});
}

test "TestNavigationBarItemsImports" {
    const content =
        \\import d1 from "a";
        \\
        \\import { a } from "a";
        \\
        \\import { b as B } from "a" 
        \\
        \\import d2, { c, d as D } from "a" 
        \\
        \\import e = require("a");
        \\
        \\import * as ns from "a";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestAutoImportsCustomConditions" {
    const content =
        \\// @module: esnext
        \\// @moduleResolution: bundler
        \\// @customConditions: custom
        \\// @Filename: /node_modules/dep/package.json
        \\{
        \\  "name": "dep",
        \\  "version": "1.0.0",
        \\  "exports": {
        \\    ".": {
        \\      "custom": "./dist/index.js"
        \\    }
        \\  }
        \\}
        \\// @Filename: /node_modules/dep/dist/index.d.ts
        \\export const dep: number;
        \\// @Filename: /index.ts
        \\dep/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"dep"}, null );
}

test "TestSemanticModernClassificationVariables" {
    const content =
        \\  var x = 9, y1 = [x];
        \\  try {
        \\    for (const s of y1) { x = s }
        \\  } catch (e) {
        \\    throw y1;
        \\  }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "variable.declaration", .Text = "x"},
//         .{.Type = "variable.declaration", .Text = "y1"},
//         .{.Type = "variable", .Text = "x"},
//         .{.Type = "variable.declaration.readonly.local", .Text = "s"},
//         .{.Type = "variable", .Text = "y1"},
//         .{.Type = "variable", .Text = "x"},
//         .{.Type = "variable.readonly.local", .Text = "s"},
//         .{.Type = "variable.declaration.local", .Text = "e"},
//         .{.Type = "variable", .Text = "y1"},
//     });
}

test "TestGetJavaScriptCompletions16" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: file.js
        \\"use strict";
        \\
        \\class Something {
        \\
        \\    /**
        \\     * @param {number} a
        \\     */
        \\    constructor(a, b) {
        \\        a/*body*/
        \\    }
        \\
        \\    /**
        \\     * @param {number} a
        \\     */
        \\    method(a) {
        \\        a/*method*/
        \\    }
        \\}
        \\let x = new Something(/*sig*/);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "body");
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
    _ = f.GoToMarker(undefined, "sig");
    // try f.VerifySignatureHelp(undefined, .{.Text = "Something(a: number, b: any): Something"});
    _ = f.GoToMarker(undefined, "method");
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
}

test "TestFunctionFormatting" {
    const content =
        \\var foo = foo(function () {
        \\    /**/function foo  ()  {}}    );
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "");
    try f.VerifyCurrentLineContent(undefined, "    function foo() { }");
}

test "TestGetOccurrencesIsDefinitionOfStringNamedProperty" {
    const content =
        \\let o = { /*1*/"/*2*/x": 12 };
        \\let y = o./*3*/x;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestTsxCompletionOnClosingTag1" {
    const content =
        \\//@Filename: file.tsx
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\        div: { ONE: string; TWO: number; }
        \\    }
        \\}
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

test "TestCompletionsElementAccessNumeric" {
    const content =
        \\// @target: esnext
        \\type Tup = [
        \\    /**
        \\     * The first label
        \\     */
        \\    lbl1: number,
        \\    /**
        \\     * The second label
        \\     */
        \\    lbl2: number
        \\];
        \\declare var x: Tup;
        \\x[|./**/|]
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
//                     .Label =      "0",
//                     .InsertText = undefined("[0]"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "The first label",
//                         },
//                     },
//                     .Detail = undefined("(property) 0: number (lbl1)"),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "0",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =      "1",
//                     .InsertText = undefined("[1]"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "The second label",
//                         },
//                     },
//                     .Detail = undefined("(property) 1: number (lbl2)"),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "1",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestCompletionWithNamespaceInsideFunction" {
    const content =
        \\function f() {
        \\    namespace n {
        \\        interface I {
        \\            x: number
        \\        }
        \\        /*1*/
        \\    }
        \\    /*2*/
        \\}
        \\/*3*/
        \\function f2() {
        \\    namespace n2 {
        \\        class I2 {
        \\            x: number
        \\        }
        \\        /*11*/
        \\    }
        \\    /*22*/
        \\}
        \\/*33*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"1", "2", "3"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "f",
//                     .Detail = undefined("function f(): void"),
//                 },
//             },
//             .Excludes = &.{
//                 "n",
//                 "I",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "11", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "f2",
//                     .Detail = undefined("function f2(): void"),
//                 },
//                 &.{
//                     .Label =  "n2",
//                     .Detail = undefined("namespace n2"),
//                 },
//                 &.{
//                     .Label =  "I2",
//                     .Detail = undefined("class I2"),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "22", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "f2",
//                     .Detail = undefined("function f2(): void"),
//                 },
//                 &.{
//                     .Label =  "n2",
//                     .Detail = undefined("namespace n2"),
//                 },
//             },
//             .Excludes = &.{
//                 "I2",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "33", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "f2",
//                     .Detail = undefined("function f2(): void"),
//                 },
//             },
//             .Excludes = &.{
//                 "n2",
//                 "I2",
//             },
//         },
//     });
}

test "TestGetJavaScriptCompletions14" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: file1.js
        \\interface Number {
        \\    toExponential(fractionDigits?: number): string;
        \\}
        \\var x = 1;
        \\x./*1*/
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
//                     .Label = "toExponential",
//                     .Kind =  undefined(lsproto.CompletionItemKindMethod),
//                 },
//             },
//         },
//     });
}

test "TestCompletionsLiteralOnPropertyValueMatchingGeneric" {
    const content =
        \\// @Filename: /a.tsx
        \\declare function bar1<P extends "" | "bar" | "baz">(p: { type: P }): void;
        \\
        \\bar1({ type: "/*ts*/" })
        \\
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
//                 "",
//                 "bar",
//                 "baz",
//             },
//         },
//     });
}

test "TestNavigationBarItemsFunctionProperties" {
    const content =
        \\(function(){
        \\var A;
        \\A/*1*/
        \\.a = function() { };
        \\})();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestCompletionsPathsJsonModuleWithAmd" {
    const content =
        \\// @module: amd
        \\// @resolveJsonModule: true
        \\// @Filename: /project/test.json
        \\not read
        \\// @Filename: /project/index.ts
        \\import { } from ".//**/";
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

test "TestGetJavaScriptCompletions2" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: Foo.js
        \\/** @type {(number|string)} */
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
//                     .Label = "valueOf",
//                     .Kind =  undefined(lsproto.CompletionItemKindMethod),
//                 },
//             },
//         },
//     });
}

test "TestGoToImplementationLocal_03" {
    const content =
        \\let [|he/*local_var*/llo|] = {};
        \\
        \\x.hello();
        \\
        \\hello = {};
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "local_var");
}

test "TestTsxCompletionInFunctionExpressionOfChildrenCallback1" {
    const content =
        \\//@module: commonjs
        \\//@jsx: preserve
        \\// @Filename: 1.tsx
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\    }
        \\    interface ElementAttributesProperty { props; }
        \\    interface ElementChildrenAttribute { children; }
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
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "Name",
//             },
//         },
//     });
}

test "TestNavigationBarNamespaceImportWithNoName" {
    const content =
        \\import *{} from 'foo';
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestCompletionsDefaultExport" {
    const content =
        \\// @Filename: /a.ts
        \\export default function f() {}
        \\// @Filename: /b.ts
        \\import * as a from "./a";
        \\a./**/;
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
//                     .Label =  "default",
//                     .Detail = undefined("function f(): void"),
//                 },
//             },
//         },
//     });
}

test "TestJsDocSignature_43394" {
    const content =
        \\/**
        \\ * @typedef {Object} Foo
        \\ * @property {number} ...
        \\ * /**/@typedef {number} Bar
        \\ */
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSignatureHelp(undefined);
}

test "TestTsxFindAllReferences4" {
    const content =
        \\//@Filename: file.tsx
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\    }
        \\    interface ElementAttributesProperty { props }
        \\}
        \\/*1*/class /*2*/MyClass {
        \\  props: {
        \\    name?: string;
        \\    size?: number;
        \\}
        \\
        \\
        \\var x = /*3*/</*4*/MyClass name='hello'><//*5*/MyClass>;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5");
}

test "TestCompletionsImport_umdDefaultNoCrash1" {
    const content =
        \\// @moduleResolution: bundler
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: /node_modules/dottie/package.json
        \\{
        \\  "name": "dottie",
        \\  "main": "dottie.js"
        \\}
        \\// @Filename: /node_modules/dottie/dottie.js
        \\(function (undefined) {
        \\  var root = this;
        \\
        \\  var Dottie = function () {};
        \\
        \\  Dottie["default"] = function (object, path, value) {};
        \\
        \\  if (typeof module !== "undefined" && module.exports) {
        \\    exports = module.exports = Dottie;
        \\  } else {
        \\    root["Dottie"] = Dottie;
        \\    root["Dot"] = Dottie;
        \\
        \\    if (typeof define === "function") {
        \\      define([], function () {
        \\        return Dottie;
        \\      });
        \\    }
        \\  }
        \\})();
        \\// @Filename: /src/index.js
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
//                     .Label =               "Dottie",
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "dottie",
//                         },
//                     },
//                     .SortText = undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
}

test "TestQuickInfoForNamedTupleMember" {
    const content =
        \\type foo = [/**/x: string];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "string", "");
}

test "TestAutoImportPackageJsonImports_capsInPath2" {
    const content =
        \\// @module: node18
        \\// @Filename: /Dev/package.json
        \\{
        \\  "imports": {
        \\    "#thing/*": "./src/*.js"
        \\  }
        \\}
        \\// @Filename: /Dev/src/something.ts
        \\export function something(name: string): any;
        \\// @Filename: /Dev/a.ts
        \\something/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"#thing/something"}, null );
}

test "TestGoToImplementationInterface_06" {
    const content =
        \\interface Fo/*interface_definition*/o {
        \\    new (a: number): SomeOtherType;
        \\}
        \\
        \\interface SomeOtherType {}
        \\
        \\let x: Foo = [|class { constructor (a: number) {} }|];
        \\let y = <Foo> [|class { constructor (a: number) {} }|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "interface_definition");
}

test "TestNavigationBarInitializerSpans" {
    const content =
        \\// get the name for the navbar from the variable name rather than the function name
        \\const [|[|x|] = () => { var [|a|]; }|];
        \\const [|[|f|] = function f() { var [|b|]; }|];
        \\const [|[|y|] = { [|[|z|]: function z() { var [|c|]; }|] }|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestGenericParameterHelpTypeReferences" {
    const content =
        \\interface IFoo { }
        \\
        \\class testClass<T extends IFoo, U, M extends IFoo> {
        \\    constructor(a:T, b:U, c:M){ }
        \\}
        \\
        \\// Generic types
        \\testClass</*type1*/
        \\var x : testClass</*type2*/
        \\class Bar<T> extends testClass</*type3*/
        \\var x : testClass<,, /*type4*/any>;
        \\
        \\interface I<T> {}
        \\let i: I</*interface*/>;
        \\
        \\type Ty<T> = T;
        \\let t: Ty</*typeAlias*/>;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "type1");
    // try f.VerifySignatureHelp(undefined, .{.Text = "testClass<T extends IFoo, U, M extends IFoo>", .ParameterName = "T", .ParameterSpan = "T extends IFoo"});
    _ = f.GoToMarker(undefined, "type2");
    // try f.VerifySignatureHelp(undefined, .{.Text = "testClass<T extends IFoo, U, M extends IFoo>", .ParameterName = "T", .ParameterSpan = "T extends IFoo"});
    _ = f.GoToMarker(undefined, "type3");
    // try f.VerifySignatureHelp(undefined, .{.Text = "testClass<T extends IFoo, U, M extends IFoo>", .ParameterName = "T", .ParameterSpan = "T extends IFoo"});
    _ = f.GoToMarker(undefined, "type4");
    // try f.VerifySignatureHelp(undefined, .{.ParameterName = "M", .ParameterSpan = "M extends IFoo"});
    _ = f.GoToMarker(undefined, "interface");
    // try f.VerifySignatureHelp(undefined, .{.Text = "I<T>", .ParameterName = "T", .ParameterSpan = "T"});
    _ = f.GoToMarker(undefined, "typeAlias");
    // try f.VerifySignatureHelp(undefined, .{.Text = "Ty<T>", .ParameterName = "T", .ParameterSpan = "T"});
}

test "TestGoToDefinitionOverriddenMember19" {
    const content =
        \\// @strict: true
        \\// @target: esnext
        \\// @lib: esnext
        \\const prop = "foo" as const;
        \\
        \\abstract class A {
        \\  static readonly /*2*/[prop] = "A";
        \\}
        \\
        \\export class B extends A {
        \\  static [|/*1*/override|] readonly [prop] = "B";
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestReferencesForStatic" {
    const content =
        \\// @Filename: referencesOnStatic_1.ts
        \\var n = 43;
        \\
        \\class foo {
        \\    /*1*/static /*2*/n = '';
        \\
        \\    public bar() {
        \\        foo./*3*/n = "'";
        \\        if(foo./*4*/n) {
        \\            var x = foo./*5*/n;
        \\        }
        \\    }
        \\}
        \\
        \\class foo2 {
        \\    private x = foo./*6*/n;
        \\    constructor() {
        \\        foo./*7*/n = x;
        \\    }
        \\
        \\    function b(n) {
        \\        n = foo./*8*/n;
        \\    }
        \\}
        \\// @Filename: referencesOnStatic_2.ts
        \\var q = foo./*9*/n;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5", "6", "7", "8", "9");
}

test "TestCompletionsOverridingMethod1" {
    const content =
        \\// @newline: LF
        \\// @Filename: h.ts
        \\// @noImplicitOverride: true
        \\class HBase {
        \\    foo(a: string): void {}
        \\}
        \\
        \\class HSub extends HBase {
        \\    f/*h*/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "h", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =      "foo",
//                     .InsertText = undefined("override foo(a: string): void {\n}"),
//                     .FilterText = undefined("foo"),
//                     .SortText =   undefined(string(ls.SortTextLocationPriority)),
//                 },
//             },
//         },
//     });
}

test "TestCodeFixAddConvertToUnknownForNonOverlappingTypes9" {
    const content =
        \\// @checkJs: true
        \\// @allowJs: true
        \\// @filename: a.js
        \\let x = /** @type {string} */ (100);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined, "Add 'unknown' conversion for non-overlapping types");
}

test "TestImportStatementCompletions_noPatternAmbient" {
    const content =
        \\// @Filename: /types.d.ts
        \\declare module "*.css" {
        \\  const styles: any;
        \\  export = styles;
        \\}
        \\// @Filename: /index.ts
        \\import style/**/
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
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestQuickInfoAssignToExistingClass" {
    const content =
        \\namespace Test {
        \\    class Mocked {
        \\        myProp: string;
        \\    }
        \\    class Tester {
        \\        willThrowError() {
        \\            Mocked = Mocked || function () { // => Error: Invalid left-hand side of assignment expression.
        \\                return { /**/myProp: "test" };
        \\            };
        \\        }
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyQuickInfoExists(undefined);
}

test "TestQuickInfoForArgumentsPropertyNameInJsMode2" {
    const content =
        \\// @allowJs: true
        \\// @filename: a.js
        \\function /*1*/f(x) {
        \\   arguments;
        \\}
        \\
        \\/*2*/f('');
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestAugmentedTypesModule5" {
    const content =
        \\declare class m3e { foo(): void }
        \\namespace m3e { export var y = 2; }
        \\var /*1*/r = new m3e();
        \\r./*2*/
        \\var /*4*/r2 = m3e./*3*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "var r: m3e", "");
    // f.VerifyCompletions(undefined, "2", &.{
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
    _ = f.Insert(undefined, "foo();");
    // f.VerifyCompletions(undefined, "3", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "y",
//             },
//         },
//     });
    _ = f.Insert(undefined, "y;");
    try f.VerifyQuickInfoAt(undefined, "4", "var r2: number", "");
}

test "TestNoErrorsAfterCompletionsRequestWithinGenericFunction1" {
    const content =
        \\// @strict: true
        \\
        \\declare function func<T extends { foo: 1 }>(arg: T): void;
        \\func({ foo: 1, bar/*1*/: 1 });
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyCompletions(undefined, null, null);
    try f.VerifyNoErrors(undefined);
}

test "TestImportNameCodeFixNewImportNodeModules0" {
    const content =
        \\[|f1/*0*/();|]
        \\// @Filename: ../package.json
        \\{ "dependencies": { "fake-module": "latest" } }
        \\// @Filename: ../node_modules/fake-module/index.ts
        \\export var v1 = 5;
        \\export function f1();
        \\// @Filename: ../node_modules/fake-module/package.json
        \\{}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { f1 } from \"fake-module\";\n\nf1();",
    }, null );
}

test "TestAutoImportCompletionExportEqualsWithDefault1" {
    const content =
        \\// @strict: true
        \\// @module: commonjs
        \\// @esModuleInterop: false
        \\// @allowSyntheticDefaultImports: false
        \\// @filename: node.ts
        \\import Container from "./container.js";
        \\import Document from "./document.js";
        \\
        \\declare namespace Node {
        \\  class Node extends Node_ {}
        \\
        \\  export { Node as default };
        \\}
        \\
        \\declare abstract class Node_ {
        \\  parent: Container | Document | undefined;
        \\}
        \\
        \\declare class Node extends Node_ {}
        \\
        \\export = Node;
        \\// @filename: document.ts
        \\import Container from "./container.js";
        \\
        \\declare namespace Document {
        \\  export { Document_ as default };
        \\}
        \\
        \\declare class Document_ extends Container {}
        \\
        \\declare class Document extends Document_ {}
        \\
        \\export = Document;
        \\// @filename: container.ts
        \\import Node from "./node.js";
        \\
        \\declare namespace Container {
        \\  export { Container_ as default };
        \\}
        \\
        \\declare abstract class Container_ extends Node {
        \\  p/*1*/
        \\}
        \\
        \\declare class Container extends Container_ {}
        \\
        \\export = Container;
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
//                     .Label =               "parent",
//                     .InsertText =          undefined("parent: Container_ | Document_ | undefined;"),
//                     .FilterText =          undefined("parent"),
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .Data = &.{
//                         .Source = "ClassMemberSnippet/",
//                     },
//                 },
//             },
//         },
//     });
    // try f.VerifyApplyCodeActionFromCompletion(undefined, undefined("1"), &.{
//         .Name =        "parent",
//         .Source =      "ClassMemberSnippet/",
//         .Description = "Includes imports of types referenced by 'parent'",
//         .NewFileContent = undefined("import Document_ from \"./document.js\";\nimport Node from \"./node.js\";\n\ndeclare namespace Container {\n  export { Container_ as default };\n}\n\ndeclare abstract class Container_ extends Node {\n  p\n}\n\ndeclare class Container extends Container_ {}\n\nexport = Container;"),
//     });
}

test "TestCompletionsImport_default_didNotExistBefore" {
    const content =
        \\// @module: esnext
        \\// @Filename: /a.ts
        \\export default function foo() {}
        \\// @Filename: /b.ts
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
    // try f.VerifyApplyCodeActionFromCompletion(undefined, undefined(""), &.{
//         .Name =        "foo",
//         .Source =      "./a",
//         .Description = "Add import from \"./a\"",
//         .NewFileContent = undefined("import foo from \"./a\";\n\nf;"),
//     });
}

test "TestOutliningSpansForArguments" {
    const content =
        \\console.log(123, 456)l;
        \\console.log(
        \\);
        \\console.log[|(
        \\    123, 456
        \\)|];
        \\console.log[|(
        \\    123,
        \\    456
        \\)|];
        \\() =>[| console.log[|(
        \\    123,
        \\    456
        \\)|]|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyOutliningSpans(undefined);
}

test "TestSemanticClassificationInstantiatedModuleWithVariableOfSameName2" {
    const content =
        \\module /*0*/M {
        \\    export interface /*1*/I {
        \\    }
        \\}
        \\
        \\module /*2*/M {
        \\    var x = 10;
        \\}
        \\
        \\var /*3*/M = {
        \\    foo: 10,
        \\    bar: 20
        \\}
        \\
        \\var v: /*4*/M./*5*/I;
        \\
        \\var x = /*6*/M;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "namespace.declaration", .Text = "M"},
//         .{.Type = "interface.declaration", .Text = "I"},
//         .{.Type = "namespace.declaration", .Text = "M"},
//         .{.Type = "variable.declaration.local", .Text = "x"},
//         .{.Type = "variable.declaration", .Text = "M"},
//         .{.Type = "property.declaration", .Text = "foo"},
//         .{.Type = "property.declaration", .Text = "bar"},
//         .{.Type = "variable.declaration", .Text = "v"},
//         .{.Type = "namespace", .Text = "M"},
//         .{.Type = "interface", .Text = "I"},
//         .{.Type = "variable.declaration", .Text = "x"},
//         .{.Type = "namespace", .Text = "M"},
//     });
}

test "TestCodeFixSpellingJs7" {
    const content =
        \\// @allowjs: true
        \\// @noEmit: true
        \\// @filename: spellingUncheckedJS.js
        \\// @ts-nocheck
        \\export var inModule = 1
        \\inmodule.toFixed()
        \\
        \\function f() {
        \\    var locals = 2 + true
        \\    locale.toFixed()
        \\}
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
        \\
        \\
        \\var object = {
        \\    spaaace: 3
        \\}
        \\object.spaaaace // error on read
        \\object.spaace = 12 // error on write
        \\object.fresh = 12 // OK
        \\other.puuuce // OK, from another file
        \\new Date().getGMTDate() // OK, from another file
        \\
        \\// No suggestions for globals from other files
        \\const atoc = setIntegral(() => console.log('ok'), 500)
        \\AudioBuffin // etc
        \\Jimmy
        \\Jon
        \\window.argle
        \\self.blargle
        \\// @filename: other.js
        \\// @ts-nocheck
        \\var Jimmy = 1
        \\var John = 2
        \\Jon // error, it's from the same file
        \\var other = {
        \\    puuce: 4
        \\}
        \\window.argle
        \\self.blargle
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyNoErrors(undefined);
}

test "TestQuickInfoWithNestedDestructuredParameterInLambda" {
    const content =
        \\// @filename: a.tsx
        \\import * as React from 'react';
        \\interface SomeInterface {
        \\    someBoolean: boolean,
        \\    someString: string;
        \\}
        \\interface SomeProps {
        \\    someProp: SomeInterface;
        \\}
        \\export const /*1*/SomeStatelessComponent = ({someProp: { someBoolean, someString}}: SomeProps) => (<div>{
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyQuickInfoExists(undefined);
}

test "TestCompletionListInObjectBindingPattern16" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @filename: a.js
        \\/**
        \\ * @typedef Foo
        \\ * @property {number} a
        \\ * @property {string} b
        \\ */
        \\
        \\/**
        \\ * @param {Foo} options
        \\ */
        \\function f({ /**/ }) {}
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

test "TestCodeFixClassImplementClassAbstractGettersAndSetters" {
    const content =
        \\abstract class A {
        \\    abstract get a(): string;
        \\    abstract set a(newName: string);
        \\
        \\    abstract get b(): number;
        \\
        \\    abstract set c(arg: number | string);
        \\
        \\    abstract accessor d: string;
        \\}
        \\
        \\class C implements A {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'A'",
        .NewFileContent = "abstract class A {\n    abstract get a(): string;\n    abstract set a(newName: string);\n\n    abstract get b(): number;\n\n    abstract set c(arg: number | string);\n\n    abstract accessor d: string;\n}\n\nclass C implements A {\n    get a(): string {\n        throw new Error(\"Method not implemented.\");\n    }\n    set a(newName: string) {\n        throw new Error(\"Method not implemented.\");\n    }\n    get b(): number {\n        throw new Error(\"Method not implemented.\");\n    }\n    set c(arg: string | number) {\n        throw new Error(\"Method not implemented.\");\n    }\n    accessor d: string;\n}",
        .Index = 0,
    });
}

test "TestTsxRename6" {
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
        \\[|declare function [|{| "contextRangeIndex": 0 |}Opt|](attributes: OptionPropBag): JSX.Element;|]
        \\let opt = [|<[|{| "contextRangeIndex": 2 |}Opt|] />|];
        \\let opt1 = [|<[|{| "contextRangeIndex": 4 |}Opt|] propx={100} propString />|];
        \\let opt2 = [|<[|{| "contextRangeIndex": 6 |}Opt|] propx={100} optional/>|];
        \\let opt3 = [|<[|{| "contextRangeIndex": 8 |}Opt|] wrong />|];
        \\let opt4 = [|<[|{| "contextRangeIndex": 10 |}Opt|] propx={100} propString="hi" />|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null , "Opt");
}

test "TestCodeFixMissingTypeAnnotationOnExports2" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\const a = 42;
        \\const b = 43;
        \\export function foo() { return a + b; }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFixAvailable(undefined, &.{"Add return type 'number'"});
    try f.VerifyCodeFix(undefined, .{
        .Description = "Add return type 'number'",
        .NewFileContent = "const a = 42;\nconst b = 43;\nexport function foo(): number { return a + b; }",
        .Index = 0,
    });
}

test "TestSignatureHelpOnOverloadsDifferentArity3" {
    const content =
        \\declare function f();
        \\declare function f(s: string);
        \\declare function f(s: string, b: boolean);
        \\declare function f(n: number, b: boolean);
        \\
        \\f(/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // try f.VerifySignatureHelp(undefined, .{.Text = "f(): any", .ParameterCount = 0, .OverloadsCount = 4});
    _ = f.Insert(undefined, "x, ");
    // try f.VerifySignatureHelp(undefined, .{.Text = "f(s: string, b: boolean): any", .ParameterCount = 2, .ParameterName = "b", .ParameterSpan = "b: boolean", .OverloadsCount = 4});
    _ = f.Insert(undefined, "x, ");
    // try f.VerifySignatureHelp(undefined, .{.Text = "f(s: string, b: boolean): any", .ParameterCount = 2, .OverloadsCount = 4});
}

test "TestNavbar_exportDefault" {
    const content =
        \\// @Filename: a.ts
        \\export default class { }
        \\// @Filename: b.ts
        \\export default class C { }
        \\// @Filename: c.ts
        \\export default function { }
        \\// @Filename: d.ts
        \\export default function Func { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "a.ts");
    try f.VerifyBaselineDocumentSymbol(undefined);
    _ = f.GoToFile(undefined, "b.ts");
    try f.VerifyBaselineDocumentSymbol(undefined);
    _ = f.GoToFile(undefined, "c.ts");
    try f.VerifyBaselineDocumentSymbol(undefined);
    _ = f.GoToFile(undefined, "d.ts");
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestCompletionListForUnicodeEscapeName" {
    const content =
        \\function \u0042 () { /*0*/ }
        \\export default function \u0043 () {}
        \\class \u0041 { /*2*/ }
        \\/*3*/
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
//                 "B",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Excludes = &.{
//                 "C",
//                 "A",
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
//                 "B",
//                 "A",
//                 "C",
//             },
//         },
//     });
}

test "TestOrganizeImports11" {
    const content =
        \\// @Filename: /test.ts
        \\import { TypeA, TypeB, TypeC, UnreferencedType } from './my-types';
        \\
        \\/**
        \\ * MyClass {@link TypeA}
        \\ */
        \\export class MyClass {
        \\
        \\  /**
        \\   * Some Property {@link TypeB}
        \\   */
        \\  public something;
        \\
        \\  /**
        \\   * Some function {@link TypeC}
        \\   */
        \\  public myMethod() {
        \\
        \\    /**
        \\     * Some lambda function {@link TypeC}
        \\     */
        \\    const someFunction = () => {
        \\      return '';
        \\    }
        \\    someFunction();
        \\  }
        \\}
        \\// @Filename: /my-types.ts
        \\ export type TypeA = string;
        \\ export class TypeB { }
        \\ export type TypeC = () => string;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyOrganizeImports(undefined,
//         "import { TypeA, TypeB, TypeC } from './my-types';\n\n/**\n * MyClass {@link TypeA}\n */\nexport class MyClass {\n\n  /**\n   * Some Property {@link TypeB}\n   */\n  public something;\n\n  /**\n   * Some function {@link TypeC}\n   */\n  public myMethod() {\n\n    /**\n     * Some lambda function {@link TypeC}\n     */\n    const someFunction = () => {\n      return '';\n    }\n    someFunction();\n  }\n}",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
}

test "TestSuperCallError0" {
    const content =
        \\class T5<T>{
        \\    constructor(public bar: T) { }
        \\}
        \\class T6 extends T5<number>{
        \\    constructor() {
        \\        super();
        \\    }
        \\}/*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, "/n");
}

test "TestGoToDefinitionOverriddenMember17" {
    const content =
        \\// @strict: true
        \\// @target: esnext
        \\// @lib: esnext
        \\const entityKind = Symbol.for("drizzle:entityKind");
        \\
        \\abstract class MySqlColumn {
        \\  static readonly /*2*/[entityKind]: string = "MySqlColumn";
        \\}
        \\
        \\export class MySqlVarBinary extends MySqlColumn {
        \\  static [|/*1*/override|] readonly [entityKind]: string = "MySqlVarBinary";
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestAutoImportCrossProject_symlinks_toDist" {
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
        \\      "dep/dist/*": ["../dep/src/*"]  
        \\    }
        \\  }
        \\  "references": [{ "path": "../dep" }]
        \\}
        \\// @Filename: /home/src/workspaces/project/packages/app/src/index.ts
        \\dep/**/
        \\// @Filename: /home/src/workspaces/project/packages/dep/package.json
        \\{ "name": "dep", "main": "dist/index.js", "types": "dist/index.d.ts" }
        \\// @Filename: /home/src/workspaces/project/packages/dep/tsconfig.json
        \\{
        \\  "compilerOptions": { "lib": ["es5"], "outDir": "dist", "rootDir": "src", "module": "commonjs" }
        \\}
        \\// @Filename: /home/src/workspaces/project/packages/dep/src/index.ts
        \\import "./sub/folder";
        \\// @Filename: /home/src/workspaces/project/packages/dep/src/sub/folder/index.ts
        \\export const dep = 0;
        \\// @link: /home/src/workspaces/project/packages/dep -> /home/src/workspaces/project/packages/app/node_modules/dep
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { dep } from \"dep/dist/sub/folder\";\n\ndep",
    }, null );
}

test "TestImportNameCodeFixNewImportAllowSyntheticDefaultImports3" {
    const content =
        \\// @AllowSyntheticDefaultImports: false
        \\// @Module: commonjs
        \\// @Filename: a/f1.ts
        \\[|export var x = 0;
        \\bar/*0*/();|]
        \\// @Filename: a/foo.d.ts
        \\declare function bar(): number;
        \\export = bar;
        \\export as namespace bar;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import bar = require(\"./foo\");\n\nexport var x = 0;\nbar();",
    }, null );
}

test "TestCompletionListForObjectSpread" {
    const content =
        \\let o = { a: 1, b: 'no' }
        \\let o2 = { b: 'yes', c: true }
        \\let swap = { a: 'yes', b: -1 };
        \\let addAfter: { a: number, b: string, c: boolean } =
        \\    { ...o, c: false }
        \\let addBefore: { a: number, b: string, c: boolean } =
        \\    { c: false, ...o }
        \\let ignore: { a: number, b: string } =
        \\    { b: 'ignored', ...o }
        \\ignore./*1*/a;
        \\let combinedNestedChangeType: { a: number, b: boolean, c: number } =
        \\    { ...{ a: 1, ...{ b: false, c: 'overriden' } }, c: -1 }
        \\combinedNestedChangeType./*2*/a;
        \\let spreadNull: { a: number } =
        \\    { a: 7, ...null }
        \\let spreadUndefined: { a: number } =
        \\    { a: 7, ...undefined }
        \\spreadNull./*3*/a;
        \\spreadUndefined./*4*/a;
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
//                     .Label =  "a",
//                     .Detail = undefined("(property) a: number"),
//                 },
//                 &.{
//                     .Label =  "b",
//                     .Detail = undefined("(property) b: string"),
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
//                     .Label =  "a",
//                     .Detail = undefined("(property) a: number"),
//                 },
//                 &.{
//                     .Label =  "b",
//                     .Detail = undefined("(property) b: boolean"),
//                 },
//                 &.{
//                     .Label =  "c",
//                     .Detail = undefined("(property) c: number"),
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
//             .Exact = &.{
//                 &.{
//                     .Label =  "a",
//                     .Detail = undefined("(property) a: number"),
//                 },
//             },
//         },
//     });
}

test "TestCompletionForStringLiteral_mappedTypeMembers" {
    const content =
        \\type Foo = {
        \\   a: string;
        \\   b: string;
        \\};
        \\
        \\type A = Readonly<Foo>;
        \\type B = A["[|/**/|]"]
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
//                     .Label = "a",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "a",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label = "b",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "b",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestNavigationBarComputedPropertyName" {
    const content =
        \\function F(key, value) {
        \\    return {
        \\        [key]: value,
        \\        "prop": true
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestGetJavaScriptSyntacticDiagnostics15" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\function F(public p) { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineNonSuggestionDiagnostics(undefined);
}

test "TestNgProxy2" {
    const content =
        \\// @Filename: tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "lib": ["es5"],
        \\        "plugins": [
        \\            { "name": "invalidmodulename" }
        \\        ]
        \\    },
        \\    "files": ["a.ts"]
        \\}
        \\// @Filename: a.ts
        \\let x = [1, 2];
        \\x/**/
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyQuickInfoIs(undefined, "let x: number[]", "");
}

test "TestQuickInfoDisplayPartsFunction" {
    const content =
        \\function /*1*/foo(param: string, optionalParam?: string, paramWithInitializer = "hello", ...restParam: string[]) {
        \\}
        \\function /*2*/foowithoverload(a: string): string;
        \\function /*3*/foowithoverload(a: number): number;
        \\function /*4*/foowithoverload(a: any): any {
        \\    return a;
        \\}
        \\function /*5*/foowith3overload(a: string): string;
        \\function /*6*/foowith3overload(a: number): number;
        \\function /*7*/foowith3overload(a: boolean): boolean;
        \\function /*8*/foowith3overload(a: any): any {
        \\    return a;
        \\}
        \\/*9*/foo("hello");
        \\/*10*/foowithoverload("hello");
        \\/*11*/foowithoverload(10);
        \\/*12*/foowith3overload("hello");
        \\/*13*/foowith3overload(10);
        \\/*14*/foowith3overload(true);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestGoToDefinitionObjectBindingElementPropertyName01" {
    const content =
        \\interface I {
        \\    /*def*/property1: number;
        \\    property2: string;
        \\}
        \\
        \\var foo: I;
        \\var { [|/*use*/property1|]: prop1 } = foo;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "use");
}

test "TestFormatConflictDiff3Marker1" {
    const content =
        \\class C {
        \\<<<<<<< HEAD
        \\v = 1;
        \\||||||| merged common ancestors
        \\v = 3;
        \\=======
        \\v = 2;
        \\>>>>>>> Branch - a
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    try f.VerifyCurrentFileContent(undefined, "class C {\n<<<<<<< HEAD\n    v = 1;\n||||||| merged common ancestors\nv = 3;\n=======\nv = 2;\n>>>>>>> Branch - a\n}");
}

test "TestRenameJsSpecialAssignmentRhs2" {
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
    // try f.VerifyBaselineRename(undefined, null );
}

test "TestRenameReferenceFromLinkTag2" {
    const content =
        \\// @Filename: /a.ts
        \\enum E {
        \\    /** {@link /**/Foo} */
        \\    Foo
        \\}
        \\interface Foo {
        \\    foo: E.Foo;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, null , "");
}

test "TestAutoImportTypeImport5" {
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
        \\export type y = 8
        \\export const Y = 9;
        \\export const Z = 10;
        \\// @Filename: /exports2.ts
        \\export const d = 0;
        \\export const D = 1;
        \\export const e = 2;
        \\export const E = 3;
        \\// @Filename: /index0.ts
        \\import { type X, type Y, type Z } from "./exports1";
        \\const foo: x/*0*/;
        \\const bar: y;
        \\// @Filename: /index1.ts
        \\import { A, B, type X, type Y, type Z } from "./exports1";
        \\const foo: x/*1*/;
        \\const bar: y;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "0");
    // try f.VerifyImportFixAtPosition(undefined, &.{
//         "import { type x, type X, type Y, type Z } from \"./exports1\";\nconst foo: x;\nconst bar: y;",
//         "import { type X, type y, type Y, type Z } from \"./exports1\";\nconst foo: x;\nconst bar: y;",
//     }, &.{.OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderLast});
    // try f.VerifyImportFixAtPosition(undefined, &.{
//         "import { type x, type X, type Y, type Z } from \"./exports1\";\nconst foo: x;\nconst bar: y;",
//         "import { type X, type y, type Y, type Z } from \"./exports1\";\nconst foo: x;\nconst bar: y;",
//     }, &.{.OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderLast});
    // try f.VerifyImportFixAtPosition(undefined, &.{
//         "import { type x, type X, type Y, type Z } from \"./exports1\";\nconst foo: x;\nconst bar: y;",
//         "import { type X, type y, type Y, type Z } from \"./exports1\";\nconst foo: x;\nconst bar: y;",
//     }, &.{.OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderInline});
    // try f.VerifyImportFixAtPosition(undefined, &.{
//         "import { type x, type X, type Y, type Z } from \"./exports1\";\nconst foo: x;\nconst bar: y;",
//         "import { type X, type y, type Y, type Z } from \"./exports1\";\nconst foo: x;\nconst bar: y;",
//     }, &.{.OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderInline});
    // try f.VerifyImportFixAtPosition(undefined, &.{
//         "import { type x, type X, type Y, type Z } from \"./exports1\";\nconst foo: x;\nconst bar: y;",
//         "import { type X, type y, type Y, type Z } from \"./exports1\";\nconst foo: x;\nconst bar: y;",
//     }, &.{.OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderFirst});
    // try f.VerifyImportFixAtPosition(undefined, &.{
//         "import { type x, type X, type Y, type Z } from \"./exports1\";\nconst foo: x;\nconst bar: y;",
//         "import { type X, type y, type Y, type Z } from \"./exports1\";\nconst foo: x;\nconst bar: y;",
//     }, &.{.OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderFirst});
    _ = f.GoToMarker(undefined, "1");
    // try f.VerifyImportFixAtPosition(undefined, &.{
//         "import { A, B, type x, type X, type Y, type Z } from \"./exports1\";\nconst foo: x;\nconst bar: y;",
//         "import { A, B, type X, type y, type Y, type Z } from \"./exports1\";\nconst foo: x;\nconst bar: y;",
//     }, &.{.OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderLast});
    // try f.VerifyImportFixAtPosition(undefined, &.{
//         "import { A, B, type x, type X, type Y, type Z } from \"./exports1\";\nconst foo: x;\nconst bar: y;",
//         "import { A, B, type X, type y, type Y, type Z } from \"./exports1\";\nconst foo: x;\nconst bar: y;",
//     }, &.{.OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderLast});
}

test "TestQuickInforForSucessiveInferencesIsNotAny" {
    const content =
        \\declare function schema<T> (value : T) : {field : T};
        \\
        \\declare const b: boolean;
        \\const obj/*1*/ = schema(b);
        \\const actualTypeOfNested/*2*/ = schema(obj);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "const obj: {\n    field: boolean;\n}", "");
    try f.VerifyQuickInfoAt(undefined, "2", "const actualTypeOfNested: {\n    field: {\n        field: boolean;\n    };\n}", "");
}

test "TestImportNameCodeFix_uriStyleNodeCoreModules2" {
    const content =
        \\// @module: commonjs
        \\// @Filename: /node_modules/@types/node/index.d.ts
        \\declare module "fs" { function writeFile(): void }
        \\declare module "fs/promises" { function writeFile(): Promise<void> }
        \\declare module "node:fs" { export * from "fs"; }
        \\declare module "node:fs/promises" { export * from "fs/promises"; }
        \\// @Filename: /other.ts
        \\import "node:fs/promises";
        \\// @Filename: /index.ts
        \\writeFile/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"node:fs", "node:fs/promises"}, null );
    _ = f.GoToFile(undefined, "/other.ts");
    _ = f.ReplaceLine(undefined, 0, "\n");
    _ = f.GoToFile(undefined, "/index.ts");
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"fs", "fs/promises", "node:fs", "node:fs/promises"}, null );
    _ = f.GoToFile(undefined, "/other.ts");
    _ = f.ReplaceLine(undefined, 0, "import \"node:fs/promises\";\n");
    _ = f.GoToFile(undefined, "/index.ts");
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"node:fs", "node:fs/promises"}, null );
}

test "TestGetOccurrencesPublic1" {
    const content =
        \\namespace m {
        \\    export class C1 {
        \\        [|public|] pub1;
        \\        [|public|] pub2;
        \\        private priv1;
        \\        private priv2;
        \\        protected prot1;
        \\        protected prot2;
        \\
        \\        [|public|] public;
        \\        private private;
        \\        protected protected;
        \\
        \\        [|public|] constructor([|public|] a, private b, protected c, [|public|] d, private e, protected f) {
        \\            this.public = 10;
        \\            this.private = 10;
        \\            this.protected = 10;
        \\        }
        \\
        \\        [|public|] get x() { return 10; }
        \\        [|public|] set x(value) { }
        \\
        \\        [|public|] static statPub;
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

test "TestFixExactOptionalUnassignableProperties3" {
    const content =
        \\// @strictNullChecks: true
        \\// @exactOptionalPropertyTypes: true
        \\// @Filename: fixExactOptionalUnassignableProperties2.ts
        \\import { INodeModules } from 'foo'
        \\interface J {
        \\    a?: number | undefined
        \\}
        \\declare var inm: INodeModules
        \\declare var j: J
        \\inm/**/ = j
        \\console.log(inm)
        \\// @Filename: node_modules/@types/foo/index.d.ts
        \\export interface INodeModules {
        \\    a?: number
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined);
}

test "TestCompletionListInObjectBindingPattern03" {
    const content =
        \\interface I {
        \\    property1: number;
        \\    property2: string;
        \\}
        \\
        \\var foo: I;
        \\var { property1: /**/ } = foo;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, "", null);
}

test "TestImportCompletionsPackageJsonImportsPattern_ts_ts" {
    const content =
        \\// @module: node18
        \\// @Filename: /package.json
        \\{
        \\  "imports": {
        \\    "#*.ts": "./src/*.ts"
        \\  }
        \\}
        \\// @Filename: /src/something.ts
        \\export function something(name: string): any;
        \\// @Filename: /a.ts
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
//                 "#something.ts",
//             },
//         },
//     });
}

test "TestGetJavaScriptCompletions_tsCheck" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\// @ts-check
        \\interface I { a: number; b: number; }
        \\interface J { b: number; c: number; }
        \\declare const ij: I | J;
        \\ij./**/
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
//                 "b",
//             },
//         },
//     });
}

test "TestRenameInfoForFunctionExpression01" {
    const content =
        \\var x = function /**/[|f|](g: any, h: any) {
        \\    f(f, g);
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyRenameSucceeded(undefined, null );
}

test "TestAutoImportTypeImport2" {
    const content =
        \\// @verbatimModuleSyntax: true
        \\// @target: esnext
        \\// @Filename: /foo.ts
        \\export const A = 1;
        \\export type B = { x: number };
        \\export type C = 1;
        \\export class D = { y: string };
        \\// @Filename: /test.ts
        \\import { A, type C, D } from './foo';
        \\const b: B/**/ | C;
        \\console.log(A, D);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // try f.VerifyImportFixAtPosition(undefined, &.{
//         "import { A, type B, type C, D } from './foo';\nconst b: B | C;\nconsole.log(A, D);",
//     }, &.{.OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderInline});
    // try f.VerifyImportFixAtPosition(undefined, &.{
//         "import { A, type C, D, type B } from './foo';\nconst b: B | C;\nconsole.log(A, D);",
//     }, &.{.OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderLast});
    // try f.VerifyImportFixAtPosition(undefined, &.{
//         "import { A, type C, D, type B } from './foo';\nconst b: B | C;\nconsole.log(A, D);",
//     }, &.{.OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderFirst});
}

test "TestQuickInfoOnJsxNamespacedName" {
    const content =
        \\// @jsx: react
        \\// @Filename: /types.d.ts
        \\declare namespace JSX {
        \\    interface IntrinsicElements { ['a:b']: { a: string }; }
        \\}
        \\// @filename: /a.tsx
        \\</**/a:b a="accepted" b="rejected" />;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestCompletionListInUnclosedVoidExpression01" {
    const content =
        \\var x;
        \\var y = (p) => void /*1*/
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

test "TestAutoImportProvider4" {
    const content =
        \\// @Filename: /home/src/workspaces/project/a/package.json
        \\{ "dependencies": { "b": "*" } }
        \\// @Filename: /home/src/workspaces/project/a/tsconfig.json
        \\{ "compilerOptions": { "lib": ["es5"], "module": "commonjs", "target": "esnext" }, "references": [{ "path": "../b" }] }
        \\// @Filename: /home/src/workspaces/project/a/index.ts
        \\new Shape/**/
        \\// @Filename: /home/src/workspaces/project/b/package.json
        \\{ "types": "out/index.d.ts" }
        \\// @Filename: /home/src/workspaces/project/b/tsconfig.json
        \\{ "compilerOptions": { "lib": ["es5"], "outDir": "out", "composite": true } }
        \\// @Filename: /home/src/workspaces/project/b/index.ts
        \\export class Shape {}
        \\// @link: /home/src/workspaces/project/b -> /home/src/workspaces/project/a/node_modules/b
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { Shape } from \"b\";\n\nnew Shape",
    }, null );
}

test "TestTsxCompletion11" {
    const content =
        \\//@module: commonjs
        \\//@jsx: preserve
        \\//@Filename: exporter.tsx
        \\export class Thing { }
        \\//@Filename: file.tsx
        \\import {Thing} from './exporter';
        \\var x1 = <div></**/
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
//                 "Thing",
//             },
//         },
//     });
}

test "TestCompletionsOverridingMethodCrash1" {
    const content =
        \\// @newline: LF
        \\// @Filename: a.ts
        \\declare class Component<T> {
        \\    setState(stateHandler: ((oldState: T, newState: T) => void)): void;
        \\}
        \\
        \\class SubComponent extends Component<{}> {
        \\    /*$*/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "$", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =      "setState",
//                     .InsertText = undefined("setState(stateHandler: (oldState: {}, newState: {}) => void): void {\n}"),
//                     .FilterText = undefined("setState"),
//                     .SortText =   undefined(string(ls.SortTextLocationPriority)),
//                 },
//             },
//         },
//     });
}

test "TestImportFixWithMultipleModuleExportAssignment" {
    const content =
        \\// @module: esnext
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: /a.js
        \\function f() {}
        \\module.exports = f;
        \\module.exports = 42;
        \\// @Filename: /b.js
        \\export const foo = 0;
        \\// @Filename: /c.js
        \\foo
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/c.js");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "const { foo } = require(\"./b\");\n\nfoo",
    }, null );
}

test "TestRenameStringLiteralTypes5" {
    const content =
        \\type T = {
        \\    "Prop 1": string;
        \\}
        \\
        \\declare const fn: <K extends keyof T>(p: K) => void
        \\
        \\fn("Prop 1"/**/)
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, null , "");
}

test "TestGetJavaScriptCompletions22" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: file.js
        \\const abc = {};
        \\({./*1*/});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, ".");
    _ = f.VerifyCompletions(undefined, null, null);
}

test "TestSmartSelection_simple2" {
    const content =
        \\export interface IService {
        \\  _serviceBrand: any;
        \\
        \\  open(ho/*1*/st: number, data: any): Promise<any>;
        \\  bar(): void/*2*/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSelectionRanges(undefined);
}

test "TestAutoImportPackageJsonImports_js" {
    const content =
        \\// @module: node18
        \\// @Filename: /package.json
        \\{
        \\  "imports": {
        \\    "#thing": "./src/something.js"
        \\  }
        \\}
        \\// @Filename: /src/something.ts
        \\export function something(name: string): any;
        \\// @Filename: /a.ts
        \\something/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"#thing"}, null );
}

test "TestJavaScriptModulesError1" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: Foo.js
        \\define('mod1', ['a'], /**/function(a, b) {
        \\    
        \\});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
}

test "TestImplementation01" {
    const content =
        \\// @lib: es5
        \\interface Fo/*1*/o {}
        \\class /*2*/Bar implements Foo {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // try f.VerifyBaselineGoToImplementation(undefined, "1");
}

test "TestCompletionsImport_require" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.ts
        \\export const foo = 0;
        \\// @Filename: /b.js
        \\import * as s from "something";
        \\fo/*b*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "b", &.{
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
//                     .Detail =              undefined("const foo: 0"),
//                     .Kind =                undefined(lsproto.CompletionItemKindVariable),
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
    // try f.VerifyApplyCodeActionFromCompletion(undefined, undefined("b"), &.{
//         .Name =        "foo",
//         .Source =      "./a",
//         .Description = "Add import from \"./a\"",
//         .NewFileContent = undefined("import * as s from \"something\";\nimport { foo } from \"./a\";\nfo"),
//     });
}

test "TestOrganizeImports12" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /test.js
        \\declare export default class A {}
        \\declare export { a, b };
        \\declare export * from "foo";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyOrganizeImports(undefined,
//         "declare export default class A {}\ndeclare export * from \"foo\";\ndeclare export { a, b };\n",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
}

test "TestJsxAriaLikeCompletions" {
    const content =
        \\//@Filename: file.tsx
        \\declare var React: any;
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\        div: { "aria-whatever"?: string  }
        \\    }
        \\    interface ElementAttributesProperty { props: any }
        \\}
        \\const a = <div {...{}} /*1*/></div>;
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
//                     .Label =      "aria-whatever?",
//                     .InsertText = undefined("aria-whatever"),
//                     .FilterText = undefined("aria-whatever"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//             },
//         },
//     });
}

test "TestGoToDefinitionOverriddenMember13" {
    const content =
        \\// @noImplicitOverride: true
        \\class Foo {
        \\    static /*2*/m() {}
        \\}
        \\class Bar extends Foo {
        \\    static [|/*1*/override|] m() {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestCompletionsRedeclareModuleAsGlobal" {
    const content =
        \\// @esModuleInterop: true,
        \\// @target: esnext
        \\// @Filename: /myAssert.d.ts
        \\declare function assert(value:any, message?:string):void;
        \\export = assert;
        \\export as namespace assert;
        \\// @Filename: /ambient.d.ts
        \\import assert from './myAssert';
        \\
        \\type Assert = typeof assert;
        \\
        \\declare global {
        \\  const assert: Assert;
        \\}
        \\// @Filename: /index.ts
        \\/// <reference path="./ambient.d.ts" />
        \\asser/**/;
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
//                     .Label =    "assert",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestQuickInfoOnProtectedConstructorCall" {
    const content =
        \\class A {
        \\    protected constructor() {}
        \\}
        \\var x = new A(/*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyNoSignatureHelpForMarkers(undefined, "1");
}

test "TestReferencesForLabel3" {
    const content =
        \\/*1*/label: while (true) {
        \\    var label = "label";
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestCodeFixMissingTypeAnnotationOnExports36_conditional_releative" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\// @Filename: /code.ts
        \\const A = "A"
        \\const B = "B"
        \\export const AB = Math.random()? A: B;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFixAvailable(undefined, &.{"Add annotation of type '\"A\" | \"B\"'", "Add annotation of type 'typeof A | typeof B'", "Add annotation of type 'string'", "Add satisfies and an inline type assertion with '\"A\" | \"B\"'", "Add satisfies and an inline type assertion with 'typeof A | typeof B'", "Add satisfies and an inline type assertion with 'string'"});
    try f.VerifyCodeFix(undefined, .{
        .Description = "Add satisfies and an inline type assertion with 'typeof A | typeof B'",
        .NewFileContent = "const A = \"A\"\nconst B = \"B\"\nexport const AB = (Math.random() ? A : B) satisfies typeof A | typeof B as typeof A | typeof B;",
        .Index = 4,
    });
}

test "TestCompletionListImplementingInterfaceFunctions" {
    const content =
        \\interface I1 {
        \\    a(): void;
        \\    b(): void;
        \\}
        \\
        \\var imp1: I1 = {
        \\    a() {},
        \\    /*0*/
        \\}
        \\
        \\var imp2: I1 = {
        \\    a: () => {},
        \\    /*1*/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"0", "1"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "b",
//             },
//         },
//     });
}

test "TestSpaceBeforeAndAfterBinaryOperators" {
    const content =
        \\let i = 0;
        \\/*1*/(i++,i++);
        \\/*2*/(i++,++i);
        \\/*3*/(1,2);
        \\/*4*/(i++,2);
        \\/*5*/(i++,i++,++i,i--,2);
        \\let s = 'foo';
        \\/*6*/for (var i = 0,ii = 2; i < s.length; ii++,i++) {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCurrentLineContent(undefined, "(i++, i++);");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyCurrentLineContent(undefined, "(i++, ++i);");
    _ = f.GoToMarker(undefined, "3");
    try f.VerifyCurrentLineContent(undefined, "(1, 2);");
    _ = f.GoToMarker(undefined, "4");
    try f.VerifyCurrentLineContent(undefined, "(i++, 2);");
    _ = f.GoToMarker(undefined, "5");
    try f.VerifyCurrentLineContent(undefined, "(i++, i++, ++i, i--, 2);");
    _ = f.GoToMarker(undefined, "6");
    try f.VerifyCurrentLineContent(undefined, "for (var i = 0, ii = 2; i < s.length; ii++, i++) {");
}

test "TestQuickInfoDisplayPartsClassIncomplete" {
    const content =
        \\/*1*/class /*2*/ {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestRenameDestructuringFunctionParameter" {
    const content =
        \\function f([|{[|{| "contextRangeIndex": 0 |}a|]}: {[|a|]}|]) {
        \\    f({[|a|]});
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[1], f.Ranges()[3], f.Ranges()[2]);
}

test "TestIntellisenseInObjectLiteral" {
    const content =
        \\var x = 3;
        \\
        \\class Foo {
        \\    static something() {
        \\        return { "prop": /**/x };
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "var x: number", "");
}

test "TestQuickInfoLink5" {
    const content =
        \\const A = 123;
        \\/**
        \\ *  See {@link A| constant A} instead
        \\ */
        \\const /**/B = 456;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestJsDocFunctionSignatures6" {
    const content =
        \\// @allowJs: true
        \\// @Filename: Foo.js
        \\/**
        \\ * @param {string} p1 - A string param
        \\ * @param {string?} p2 - An optional param
        \\ * @param {string} [p3] - Another optional param
        \\ * @param {string} [p4="test"] - An optional param with a default value
        \\ */
        \\function f1(p1, p2, p3, p4){}
        \\f1(/*1*/'foo', /*2*/'bar', /*3*/'baz', /*4*/'qux');
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSignatureHelp(undefined);
}

test "TestCompletionsImport_sortingModuleSpecifiers" {
    const content =
        \\// @Filename: tsconfig.json
        \\{ "compilerOptions": { "module": "commonjs", "lib": ["es5"] } }
        \\// @Filename: path.d.ts
        \\declare module "path/posix" {
        \\    export function normalize(p: string): string;
        \\}
        \\declare module "path/win32" {
        \\    export function normalize(p: string): string;
        \\}
        \\declare module "path" {
        \\    export function normalize(p: string): string;
        \\}
        \\// @Filename: main.ts
        \\normalize/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
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
//                         .Label = "normalize",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "path",
//                             },
//                         },
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     },
//                     &.{
//                         .Label = "normalize",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "path/posix",
//                             },
//                         },
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     },
//                     &.{
//                         .Label = "normalize",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "path/win32",
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

test "TestSignatureHelpCallExpression" {
    const content =
        \\function fnTest(str: string, num: number) { }
        \\fnTest(/*1*/'', /*2*/5);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // try f.VerifySignatureHelp(undefined, .{.Text = "fnTest(str: string, num: number): void", .ParameterCount = 2, .ParameterName = "str", .ParameterSpan = "str: string"});
    _ = f.GoToMarker(undefined, "2");
    // try f.VerifySignatureHelp(undefined, .{.ParameterName = "num", .ParameterSpan = "num: number"});
}

test "TestRenameStringLiteralTypes2" {
    const content =
        \\type Foo = "[|a|]" | "b";
        \\
        \\class C {
        \\    p: Foo = "[|a|]";
        \\    m() {
        \\        if (this.p === "[|a|]") {}
        \\        if ("[|a|]" === this.p) {}
        \\
        \\        if (this.p !== "[|a|]") {}
        \\        if ("[|a|]" !== this.p) {}
        \\
        \\        if (this.p == "[|a|]") {}
        \\        if ("[|a|]" == this.p) {}
        \\
        \\        if (this.p != "[|a|]") {}
        \\        if ("[|a|]" != this.p) {}
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null , "a");
}

test "TestScopeOfUnionProperties" {
    const content =
        \\function f(s: string | number) {
        \\    s.constr/*1*/uctor
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , "1");
}

test "TestFormatTypeAnnotation1" {
    const content =
        \\function foo(x: number, y?: string): number {}
        \\interface Foo {
        \\    x: number;
        \\    y?: number;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.GetOptions();
    // f.Configure(undefined, opts207);
    _ = f.FormatDocument(undefined, "");
    try f.VerifyCurrentFileContent(undefined, "function foo(x : number, y ?: string) : number { }\ninterface Foo {\n    x : number;\n    y ?: number;\n}");
}

test "TestCompletionsRecommended_nonAccessibleSymbol" {
    const content =
        \\function f() {
        \\    class C {}
        \\    return (c: C) => void;
        \\}
        \\f()(new /**/);
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
//                 "C",
//             },
//         },
//     });
}

test "TestImportCompletionsPackageJsonImportsPattern" {
    const content =
        \\// @module: node18
        \\// @Filename: /package.json
        \\{
        \\  "imports": {
        \\    "#*": "./src/*"
        \\  }
        \\}
        \\// @Filename: /src/something.ts
        \\export function something(name: string): any;
        \\// @Filename: /a.ts
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
//                 "#something.js",
//             },
//         },
//     });
}

test "TestSignatureHelpAnonymousFunction" {
    const content =
        \\var anonymousFunctionTest = function(n: number, s: string): (a: number, b: string) => string {
        \\    return null;
        \\}
        \\anonymousFunctionTest(5, "")(/*anonymousFunction1*/1, /*anonymousFunction2*/"");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "anonymousFunction1");
    // try f.VerifySignatureHelp(undefined, .{.Text = "(a: number, b: string): string", .ParameterCount = 2, .ParameterName = "a", .ParameterSpan = "a: number"});
    _ = f.GoToMarker(undefined, "anonymousFunction2");
    // try f.VerifySignatureHelp(undefined, .{.ParameterName = "b", .ParameterSpan = "b: string"});
}

test "TestGoToSource17_AddsFileToProject" {
    const content =
        \\// @lib: es5
        \\// @moduleResolution: bundler
        \\// @Filename: /home/src/workspaces/project/node_modules/@types/yargs/package.json
        \\{
        \\    "name": "@types/yargs",
        \\    "version": "1.0.0",
        \\    "types": "./index.d.ts"
        \\}
        \\// @Filename: /home/src/workspaces/project/node_modules/@types/yargs/callback.d.ts
        \\export declare class Yargs { positional(): Yargs; }
        \\// @Filename: /home/src/workspaces/project/node_modules/@types/yargs/index.d.ts
        \\import { Yargs } from "./callback";
        \\export declare function command(command: string, cb: (yargs: Yargs) => void): void;
        \\// @Filename: /home/src/workspaces/project/node_modules/yargs/package.json
        \\{
        \\    "name": "yargs",
        \\    "version": "1.0.0",
        \\    "main": "index.js"
        \\}
        \\// @Filename: /home/src/workspaces/project/node_modules/yargs/callback.js
        \\export class Yargs { positional() { } }
        \\// @Filename: /home/src/workspaces/project/node_modules/yargs/index.js
        \\// Specifically didnt have ./callback import to ensure that resolving module sepcifier adds the file to project at later stage
        \\export function command(cmd, cb) { cb(Yargs) }
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\import { command } from "yargs";
        \\command("foo", yargs => {
        \\    yargs.[|/*start*/positional|]();
        \\});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // try f.VerifyBaselineGoToSourceDefinition(undefined, "start");
}

test "TestGoToImplementationThis_00" {
    const content =
        \\class [|Bar|] extends Foo {
        \\    hello() {
        \\        thi/*this_call*/s.whatever();
        \\    }
        \\
        \\    whatever() {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "this_call");
}

test "TestCompletionImportMetaWithGlobalDeclaration" {
    const content =
        \\// @Filename: a.ts
        \\import./*1*/
        \\// @Filename: b.ts
        \\declare global {
        \\  interface ImportMeta {
        \\    url: string;
        \\  }
        \\}
        \\import.meta./*2*/
        \\// @Filename: c.ts
        \\import.meta./*3*/url
        \\// @Filename: d.ts
        \\import./*4*/meta
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
//                 "meta",
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
//                 "url",
//             },
//             .Excludes = &.{
//                 "meta",
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
//                 "url",
//             },
//             .Excludes = &.{
//                 "meta",
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
//                 "meta",
//             },
//         },
//     });
}

test "TestDocumentHighlightTemplateStrings" {
    const content =
        \\type Foo = "[|a|]" | "b";
        \\
        \\class C {
        \\   p: Foo = 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , f.Ranges()[2]);
}

test "TestGetOccurrencesThrow2" {
    const content =
        \\function f(a: number) {
        \\    try {
        \\        throw "Hello";
        \\
        \\        try {
        \\            [|t/**/hrow|] 10;
        \\        }
        \\        catch (x) {
        \\            return 100;
        \\        }
        \\        finally {
        \\            throw 10;
        \\        }
        \\    }
        \\    catch (x) {
        \\        throw "Something";
        \\    }
        \\    finally {
        \\        throw "Also something";
        \\    }
        \\    if (a > 0) {
        \\        return (function () {
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
        \\    throw 10;
        \\
        \\    var unusued = [1, 2, 3, 4].map(x => { throw 4 })
        \\
        \\    return;
        \\    return true;
        \\    throw false;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestDocumentHighlightAtInheritedProperties2" {
    const content =
        \\// @Filename: file1.ts
        \\class class1 extends class1 {
        \\   [|doStuff|]() { }
        \\   [|propName|]: string;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestGenericFunctionSignatureHelp3MultiFile" {
    const content =
        \\// @Filename: genericFunctionSignatureHelp_0.ts
        \\function foo1<T>(x: number, callback: (y1: T) => number) { }
        \\// @Filename: genericFunctionSignatureHelp_1.ts
        \\function foo2<T>(x: number, callback: (y2: T) => number) { }
        \\// @Filename: genericFunctionSignatureHelp_2.ts
        \\function foo3<T>(x: number, callback: (y3: T) => number) { }
        \\// @Filename: genericFunctionSignatureHelp_3.ts
        \\function foo4<T>(x: number, callback: (y4: T) => number) { }
        \\// @Filename: genericFunctionSignatureHelp_4.ts
        \\function foo5<T>(x: number, callback: (y5: T) => number) { }
        \\// @Filename: genericFunctionSignatureHelp_5.ts
        \\function foo6<T>(x: number, callback: (y6: T) => number) { }
        \\// @Filename: genericFunctionSignatureHelp_6.ts
        \\function foo7<T>(x: number, callback: (y7: T) => number) { }
        \\// @Filename: genericFunctionSignatureHelp_7.ts
        \\foo1(/*1*/               // signature help shows y as T
        \\foo2(1,/*2*/             // signature help shows y as {}
        \\foo3(1, (/*3*/           // signature help shows y as T
        \\foo4<string>(1,/*4*/     // signature help shows y as string
        \\foo5<string>(1, (/*5*/   // signature help shows y as T
        \\foo6(1, </*6*/           // signature help shows y as {}
        \\foo7(1, <string>(/*7*/   // signature help shows y as T
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // try f.VerifySignatureHelp(undefined, .{.Text = "foo1(x: number, callback: (y1: unknown) => number): void"});
    _ = f.GoToMarker(undefined, "2");
    // try f.VerifySignatureHelp(undefined, .{.Text = "foo2(x: number, callback: (y2: unknown) => number): void"});
    _ = f.GoToMarker(undefined, "3");
    // try f.VerifySignatureHelp(undefined, .{.Text = "callback(y3: unknown): number"});
    _ = f.GoToMarker(undefined, "4");
    // try f.VerifySignatureHelp(undefined, .{.Text = "foo4(x: number, callback: (y4: string) => number): void"});
    _ = f.GoToMarker(undefined, "5");
    // try f.VerifySignatureHelp(undefined, .{.Text = "callback(y5: string): number"});
    _ = f.GoToMarker(undefined, "6");
    // try f.VerifySignatureHelp(undefined, .{.Text = "foo6(x: number, callback: (y6: unknown) => number): void"});
    _ = f.Insert(undefined, "string>(null,null);");
    _ = f.GoToMarker(undefined, "7");
    // try f.VerifySignatureHelp(undefined, .{.Text = "foo7(x: number, callback: (y7: unknown) => number): void"});
}

test "TestCompletionListPrivateNamesMethods" {
    const content =
        \\class Foo {
        \\   #x() {};
        \\   y() {};
        \\}
        \\class Bar extends Foo {
        \\   #z() {};
        \\   t() {};
        \\   constructor() {
        \\       this./*1*/
        \\       class Baz {
        \\           #z() {};
        \\           #u() {};
        \\           v() {};
        \\           constructor() {
        \\               this./*2*/
        \\               new Bar()./*3*/
        \\           }
        \\       }
        \\   }
        \\}
        \\
        \\new Foo()./*4*/
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
//             .Unsorted = &.{
//                 "#z",
//                 "t",
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
//             .Unsorted = &.{
//                 "#z",
//                 "#u",
//                 "v",
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
//                 "#z",
//                 "t",
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
//             .Exact = &.{
//                 "y",
//             },
//         },
//     });
}

test "TestJavaScriptClass4" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: Foo.js
        \\class Foo {
        \\   constructor() {
        \\       /**
        \\         * @type {string}
        \\       */
        \\       this.baz = null;
        \\   }
        \\}
        \\var x = new Foo();
        \\x/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, ".baz.");
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

test "TestCodeFixMissingTypeAnnotationOnExports40_extract_other_to_variable" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\// @lib: es2019
        \\// @Filename: /code.ts
        \\let c: string[] = [];
        \\export let o = {
        \\    p: Math.random() ? []: [
        \\        ...c
        \\    ]
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Extract to variable and replace with 'newLocal as typeof newLocal'",
        .NewFileContent = "let c: string[] = [];\nconst newLocal = Math.random() ? [] : [\n    ...c\n];\nexport let o = {\n    p: newLocal as typeof newLocal\n}",
        .Index =        2,
        .ApplyChanges = true,
    });
    try f.VerifyCodeFix(undefined, .{
        .Description = "Add annotation of type 'string[]'",
        .NewFileContent = "let c: string[] = [];\nconst newLocal: string[] = Math.random() ? [] : [\n    ...c\n];\nexport let o = {\n    p: newLocal as typeof newLocal\n}",
        .Index =        0,
        .ApplyChanges = true,
    });
}

test "TestImportCompletions_importsMap5" {
    const content =
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "module": "nodenext",
        \\    "lib": ["es5"],
        \\    "rootDir": "src",
        \\    "outDir": "dist",
        \\    "declarationDir": "types",
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/package.json
        \\{
        \\  "type": "module",
        \\  "imports": {
        \\    "#is-browser": {
        \\      "types": "./types/env/browser.d.ts",
        \\      "default": "./not-dist-on-purpose/env/browser.js"
        \\    }
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/src/env/browser.ts
        \\export const isBrowser = true;
        \\// @Filename: /home/src/workspaces/project/src/a.ts
        \\import {} from "/*1*/";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.VerifyCompletions(undefined, &.{"1"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "#is-browser",
//             },
//         },
//     });
}

test "TestGenericWithSpecializedProperties2" {
    const content =
        \\interface Foo<T> {
        \\    y: Foo<number>;
        \\    x: Foo<string>;
        \\}
        \\var f: Foo<string>;
        \\var /*1*/x = f.x; 
        \\var /*2*/y = f.y; 
        \\var f2: Foo<number>;
        \\var /*3*/x2 = f2.x; 
        \\var /*4*/y2 = f2.y; 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "var x: Foo<string>", "");
    try f.VerifyQuickInfoAt(undefined, "2", "var y: Foo<number>", "");
    try f.VerifyQuickInfoAt(undefined, "3", "var x2: Foo<string>", "");
    try f.VerifyQuickInfoAt(undefined, "4", "var y2: Foo<number>", "");
}

test "TestExportInLabeledStatement" {
    const content =
        \\// @Filename: a.ts
        \\subTitle:
        \\[|export|] const title: string
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlightsWithOptions(undefined, null , &.{f.Ranges()[0].FileName()}, f.Ranges()[0]);
}

test "TestUpdateToClassStatics" {
    const content =
        \\namespace TypeScript {
        \\    export class PullSymbol {}
        \\    export class Diagnostic {}
        \\    export class SymbolAndDiagnostics<TSymbol extends PullSymbol> {
        \\        constructor(public symbol: TSymbol,
        \\            public diagnostics: Diagnostic) {
        \\        }
        \\        /**/
        \\        public static create<TSymbol extends PullSymbol>(symbol: TSymbol, diagnostics: Diagnostic): SymbolAndDiagnostics<TSymbol> {
        \\            return new SymbolAndDiagnostics<TSymbol>(symbol, diagnostics);
        \\        }
        \\    }
        \\}
        \\namespace TypeScript {
        \\    var x : TypeScript.SymbolAndDiagnostics;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, "someNewProperty = 0;");
}

test "TestCodeFixUndeclaredPropertyAccesses" {
    const content =
        \\interface I { x: number; }
        \\let i: I;
        \\i.y;
        \\i.foo();
        \\enum E { a,b }
        \\let e: typeof E;
        \\e.a;
        \\e.c;
        \\let obj = { a: 1, b: "asdf"};
        \\obj.c;
        \\type T<U> = I | U;
        \\let t: T<number>;
        \\t.x;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFixAvailable(undefined, null);
}

test "TestNavigationBarItemsItemsExternalModules" {
    const content =
        \\export class Bar {
        \\    public s: string;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestCompletionListAtBeginningOfIdentifierInArrowFunction01" {
    const content =
        \\xyz => /*1*/x
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
//                 "xyz",
//             },
//         },
//     });
}

test "TestAutoImportSpecifierExcludeRegexes2" {
    const content =
        \\// @Filename: /tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "module": "preserve",
        \\        "paths": {
        \\            "@app/*": ["./src/*"]
        \\        }
        \\    }
        \\}
        \\// @Filename: /src/utils.ts
        \\export function add(a: number, b: number) {}
        \\// @Filename: /src/index.ts
        \\add/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"./utils"}, null );
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"@app/utils"}, &.{.AutoImportSpecifierExcludeRegexes = &.{"^\\./"}});
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"@app/utils"}, &.{.ImportModuleSpecifierPreference = "non-relative"});
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"./utils"}, &.{.ImportModuleSpecifierPreference = "non-relative", .AutoImportSpecifierExcludeRegexes = &.{"^@app/"}});
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{}, &.{.AutoImportSpecifierExcludeRegexes = &.{"utils"}});
}

test "TestInsertReturnStatementInDuplicateIdentifierFunction" {
    const content =
        \\// @strict: true
        \\class foo { };
        \\function foo() { /**/ }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyNumberOfErrorsInCurrentFile(undefined, 2);
    _ = f.Insert(undefined, "return null;");
    try f.VerifyNumberOfErrorsInCurrentFile(undefined, 2);
}

test "TestImportNameCodeFix_jsx4" {
    const content =
        \\// @jsx: react
        \\// @module: esnext
        \\// @esModuleInterop: true
        \\// @moduleResolution: bundler
        \\// @Filename: /node_modules/react/index.d.ts
        \\export = React;
        \\export as namespace React;
        \\declare namespace React {
        \\    class Component {}
        \\}
        \\// @Filename: /node_modules/react-native/index.d.ts
        \\import * as React from "react";
        \\export class Text extends React.Component {};
        \\// @Filename: /a.tsx
        \\import { Text } from "react-native";
        \\<Text></Text>;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/a.tsx");
    try f.VerifyCodeFix(undefined, .{
        .Description = "Import 'React' from \"react\"",
        .NewFileContent = "import React from \"react\";\nimport { Text } from \"react-native\";\n<Text></Text>;",
        .Index = 0,
    });
}

test "TestQuickInfoDisplayPartsIife" {
    const content =
        \\// @strictNullChecks: true
        \\var iife = (function foo/*1*/(x, y) { return x })(12);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "(local function) foo(x: number, y?: undefined): number", "");
}

test "TestGetJavaScriptSyntacticDiagnostics5" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\class C implements D { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineNonSuggestionDiagnostics(undefined);
}

test "TestUnreachableCodeAfterEdit" {
    const content =
        \\// @allowUnreachableCode: false
        \\// @lib: es2015
        \\// @Filename: /base/browser/browser.ts
        \\export const isStandalone = true;
        \\// @Filename: /base/browser/dom.ts
        \\export function addDisposableListener() {}
        \\// @Filename: /base/browser/window.ts
        \\export const mainWindow = {} as Window;
        \\// @Filename: /workbench.ts
        \\/*before*/import { isStandalone } from './base/browser/browser';
        \\import { addDisposableListener } from './base/browser/dom';
        \\import { mainWindow } from './base/browser/window';
        \\
        \\interface ISecretStorageCrypto {
        \\    seal(data: string): Promise<string>;
        \\    unseal(data: string): Promise<string>;
        \\}
        \\
        \\export class TransparentCrypto implements ISecretStorageCrypto {
        \\    async seal(data: string): Promise<string> {
        \\        return data;
        \\    }
        \\    async unseal(data: string): Promise<string> {
        \\        return data;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyNumberOfErrorsInCurrentFile(undefined, 0);
    _ = f.GoToMarker(undefined, "before");
    _ = f.Insert(undefined, "throw new Error('foo');\n");
    try f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
    _ = f.GoToMarker(undefined, "before");
    _ = f.DeleteAtCaret(undefined, 24);
    try f.VerifyNumberOfErrorsInCurrentFile(undefined, 0);
}

test "TestRegexp" {
    const content =
        \\var /**/x = /aa/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "var x: RegExp", "");
}

test "TestQuickinfoWrongComment" {
    const content =
        \\// @stableTypeOrdering: true
        \\// @lib: es5
        \\interface I {
        \\    /** The colour */
        \\    readonly colour: string
        \\}
        \\interface A extends I {
        \\    readonly colour: "red" | "green";
        \\}
        \\interface B extends I {
        \\    readonly colour: "yellow" | "green";
        \\}
        \\type F = A | B
        \\const f: F = { colour: "green" }
        \\f.colour/*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyQuickInfoIs(undefined, "(property) colour: \"green\" | \"red\" | \"yellow\"", "The colour");
}

test "TestFormatAfterPasteInString" {
    const content =
        \\/*2*/const x = f('aa/*1*/a').x()
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.Paste(undefined, "bb");
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyCurrentLineContent(undefined, "const x = f('aabba').x()");
}

test "TestGoToDefinitionTypeofThis" {
    const content =
        \\function f(/*fnDecl*/this: number) {
        \\    type X = typeof [|/*fnUse*/this|];
        \\}
        \\class /*cls*/C {
        \\    constructor() { type X = typeof [|/*clsUse*/this|]; }
        \\    get self(/*getterDecl*/this: number) { type X = typeof [|/*getterUse*/this|]; }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "fnUse", "clsUse", "getterUse");
}

test "TestFindAllRefsForDefaultExport_anonymous" {
    const content =
        \\// @Filename: /a.ts
        \\export /*1*/default 1;
        \\// @Filename: /b.ts
        \\import a from "./a";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestTypedefinition01" {
    const content =
        \\// @lib: es5
        \\// @Filename: b.ts
        \\import n = require('./a');
        \\var x/*1*/ = new n.Foo();
        \\// @Filename: a.ts
        \\export class /*2*/Foo {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // try f.VerifyBaselineGoToTypeDefinition(undefined, "1");
}

test "TestCodeFixPropertyOverrideAccess4" {
    const content =
        \\// @strict: true
        \\// @target: esnext
        \\// @lib: esnext
        \\const prop = Symbol.for('foo');
        \\
        \\class A {
        \\    [prop] = 1;
        \\}
        \\class B extends A {
        \\    get [prop]() { return 2; }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined, "fixPropertyOverrideAccessor");
}

test "TestGoToImplementationLocal_08" {
    const content =
        \\declare function [|someFunction|](): () => void;
        \\someFun/*reference*/ction();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "reference");
}

test "TestJsDocSee2" {
    const content =
        \\/** @see {/*use1*/[|foooo|]} unknown reference*/
        \\const a = ""
        \\/** @see {/*use2*/[|@bar|]} invalid tag*/
        \\const b = ""
        \\/** @see /*use3*/[|foooo|] unknown reference without brace*/
        \\const c = ""
        \\/** @see /*use4*/[|@bar|] invalid tag without brace*/
        \\const [|/*def1*/d|] = ""
        \\/** @see {/*use5*/[|d@fff|]} partial reference */
        \\const e = ""
        \\/** @see /*use6*/[|@@@@@@|] total invalid tag*/
        \\const f = ""
        \\/** @see d@{/*use7*/[|fff|]} partial reference */
        \\const g = ""
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "use1", "use2", "use3", "use4", "use5", "use6", "use7");
}

test "TestCommentsInheritanceFourslash" {
    const content =
        \\/** i1 is interface with properties*/
        \\interface i1 {
        \\    /** i1_p1*/
        \\    i1_p1: number;
        \\    /** i1_f1*/
        \\    i1_f1(): void;
        \\    /** i1_l1*/
        \\    i1_l1: () => void;
        \\    i1_nc_p1: number;
        \\    i1_nc_f1(): void;
        \\    i1_nc_l1: () => void;
        \\    p1: number;
        \\    f1(): void;
        \\    l1: () => void;
        \\    nc_p1: number;
        \\    nc_f1(): void;
        \\    nc_l1: () => void;
        \\}
        \\class c1 implements i1 {
        \\    public i1_p1: number;
        \\    public i1_f1() {
        \\    }
        \\    public i1_l1: () => void;
        \\    public i1_nc_p1: number;
        \\    public i1_nc_f1() {
        \\    }
        \\    public i1_nc_l1: () => void;
        \\    /** c1_p1*/
        \\    public p1: number;
        \\    /** c1_f1*/
        \\    public f1() {
        \\    }
        \\    /** c1_l1*/
        \\    public l1: () => void;
        \\    /** c1_nc_p1*/
        \\    public nc_p1: number;
        \\    /** c1_nc_f1*/
        \\    public nc_f1() {
        \\    }
        \\    /** c1_nc_l1*/
        \\    public nc_l1: () => void;
        \\}
        \\var i1/*1iq*/_i: /*16i*/i1;
        \\i1_i./*1*/i/*2q*/1_f1(/*2*/);
        \\i1_i.i1_n/*3q*/c_f1(/*3*/);
        \\i1_i.f/*4q*/1(/*4*/);
        \\i1_i.nc/*5q*/_f1(/*5*/);
        \\i1_i.i1/*l2q*/_l1(/*l2*/);
        \\i1_i.i1_/*l3q*/nc_l1(/*l3*/);
        \\i1_i.l/*l4q*/1(/*l4*/);
        \\i1_i.nc/*l5q*/_l1(/*l5*/);
        \\var c1/*6iq*/_i = new c1();
        \\c1_i./*6*/i1/*7q*/_f1(/*7*/);
        \\c1_i.i1_nc/*8q*/_f1(/*8*/);
        \\c1_i.f/*9q*/1(/*9*/);
        \\c1_i.nc/*10q*/_f1(/*10*/);
        \\c1_i.i1/*l7q*/_l1(/*l7*/);
        \\c1_i.i1_n/*l8q*/c_l1(/*l8*/);
        \\c1_i.l/*l9q*/1(/*l9*/);
        \\c1_i.nc/*l10q*/_l1(/*l10*/);
        \\// assign to interface
        \\i1_i = c1_i;
        \\i1_i./*11*/i1/*12q*/_f1(/*12*/);
        \\i1_i.i1_nc/*13q*/_f1(/*13*/);
        \\i1_i.f/*14q*/1(/*14*/);
        \\i1_i.nc/*15q*/_f1(/*15*/);
        \\i1_i.i1/*l12q*/_l1(/*l12*/);
        \\i1_i.i1/*l13q*/_nc_l1(/*l13*/);
        \\i1_i.l/*l14q*/1(/*l14*/);
        \\i1_i.nc/*l15q*/_l1(/*l15*/);
        \\/*16*/
        \\class c2 {
        \\    /** c2 c2_p1*/
        \\    public c2_p1: number;
        \\    /** c2 c2_f1*/
        \\    public c2_f1() {
        \\    }
        \\    /** c2 c2_prop*/
        \\    public get c2_prop() {
        \\        return 10;
        \\    }
        \\    public c2_nc_p1: number;
        \\    public c2_nc_f1() {
        \\    }
        \\    public get c2_nc_prop() {
        \\        return 10;
        \\    }
        \\    /** c2 p1*/
        \\    public p1: number;
        \\    /** c2 f1*/
        \\    public f1() {
        \\    }
        \\    /** c2 prop*/
        \\    public get prop() {
        \\        return 10;
        \\    }
        \\    public nc_p1: number;
        \\    public nc_f1() {
        \\    }
        \\    public get nc_prop() {
        \\        return 10;
        \\    }
        \\    /** c2 constructor*/
        \\    constr/*55*/uctor(a: number) {
        \\        this.c2_p1 = a;
        \\    }
        \\}
        \\class c3 extends c2 {
        \\    cons/*56*/tructor() {
        \\        su/*18sq*/per(10);
        \\        this.p1 = s/*18spropq*/uper./*18spropProp*/c2_p1;
        \\    }
        \\    /** c3 p1*/
        \\    public p1: number;
        \\    /** c3 f1*/
        \\    public f1() {
        \\    }
        \\    /** c3 prop*/
        \\    public get prop() {
        \\        return 10;
        \\    }
        \\    public nc_p1: number;
        \\    public nc_f1() {
        \\    }
        \\    public get nc_prop() {
        \\        return 10;
        \\    }
        \\}
        \\var c/*17iq*/2_i = new c/*17q*/2(/*17*/10);
        \\var c/*18iq*/3_i = new c/*18q*/3(/*18*/);
        \\c2_i./*19*/c2/*20q*/_f1(/*20*/);
        \\c2_i.c2_nc/*21q*/_f1(/*21*/);
        \\c2_i.f/*22q*/1(/*22*/);
        \\c2_i.nc/*23q*/_f1(/*23*/);
        \\c3_i./*24*/c2/*25q*/_f1(/*25*/);
        \\c3_i.c2_nc/*26q*/_f1(/*26*/);
        \\c3_i.f/*27q*/1(/*27*/);
        \\c3_i.nc/*28q*/_f1(/*28*/);
        \\// assign
        \\c2_i = c3_i;
        \\c2_i./*29*/c2/*30q*/_f1(/*30*/);
        \\c2_i.c2_nc_/*31q*/f1(/*31*/);
        \\c2_i.f/*32q*/1(/*32*/);
        \\c2_i.nc/*33q*/_f1(/*33*/);
        \\class c4 extends c2 {
        \\}
        \\var c4/*34iq*/_i = new c/*34q*/4(/*34*/10);
        \\/*35*/
        \\interface i2 {
        \\    /** i2_p1*/
        \\    i2_p1: number;
        \\    /** i2_f1*/
        \\    i2_f1(): void;
        \\    /** i2_l1*/
        \\    i2_l1: () => void;
        \\    i2_nc_p1: number;
        \\    i2_nc_f1(): void;
        \\    i2_nc_l1: () => void;
        \\    /** i2 p1*/
        \\    p1: number;
        \\    /** i2 f1*/
        \\    f1(): void;
        \\    /** i2 l1*/
        \\    l1: () => void;
        \\    nc_p1: number;
        \\    nc_f1(): void;
        \\    nc_l1: () => void;
        \\}
        \\interface i3 extends i2 {
        \\    /** i3 p1*/
        \\    p1: number;
        \\    /** i3 f1*/
        \\    f1(): void;
        \\    /** i3 l1*/
        \\    l1: () => void;
        \\    nc_p1: number;
        \\    nc_f1(): void;
        \\    nc_l1: () => void;
        \\}
        \\var i2/*36iq*/_i: /*51i*/i2;
        \\var i3/*37iq*/_i: i3;
        \\i2_i./*36*/i2/*37q*/_f1(/*37*/);
        \\i2_i.i2_n/*38q*/c_f1(/*38*/);
        \\i2_i.f/*39q*/1(/*39*/);
        \\i2_i.nc/*40q*/_f1(/*40*/);
        \\i2_i.i2_/*l37q*/l1(/*l37*/);
        \\i2_i.i2_nc/*l38q*/_l1(/*l38*/);
        \\i2_i.l/*l39q*/1(/*l39*/);
        \\i2_i.nc_/*l40q*/l1(/*l40*/);
        \\i3_i./*41*/i2_/*42q*/f1(/*42*/);
        \\i3_i.i2_nc/*43q*/_f1(/*43*/);
        \\i3_i.f/*44q*/1(/*44*/);
        \\i3_i.nc_/*45q*/f1(/*45*/);
        \\i3_i.i2_/*l42q*/l1(/*l42*/);
        \\i3_i.i2_nc/*l43q*/_l1(/*l43*/);
        \\i3_i.l/*l44q*/1(/*l44*/);
        \\i3_i.nc_/*l45q*/l1(/*l45*/);
        \\// assign to interface
        \\i2_i = i3_i;
        \\i2_i./*46*/i2/*47q*/_f1(/*47*/);
        \\i2_i.i2_nc_/*48q*/f1(/*48*/);
        \\i2_i.f/*49q*/1(/*49*/);
        \\i2_i.nc/*50q*/_f1(/*50*/);
        \\i2_i.i2_/*l47q*/l1(/*l47*/);
        \\i2_i.i2_nc/*l48q*/_l1(/*l48*/);
        \\i2_i.l/*l49q*/1(/*l49*/);
        \\i2_i.nc_/*l50q*/l1(/*l50*/);
        \\/*51*/
        \\/**c5 class*/
        \\class c5 {
        \\    public b: number;
        \\}
        \\class c6 extends c5 {
        \\    public d;
        \\    const/*57*/ructor() {
        \\        /*52*/super();
        \\        this.d = /*53*/super./*54*/b;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"1", "11"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "i1_p1",
//                     .Detail = undefined("(property) i1.i1_p1: number"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "i1_p1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "i1_f1",
//                     .Detail = undefined("(method) i1.i1_f1(): void"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "i1_f1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "i1_l1",
//                     .Detail = undefined("(property) i1.i1_l1: () => void"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "i1_l1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "i1_nc_p1",
//                     .Detail = undefined("(property) i1.i1_nc_p1: number"),
//                 },
//                 &.{
//                     .Label =  "i1_nc_f1",
//                     .Detail = undefined("(method) i1.i1_nc_f1(): void"),
//                 },
//                 &.{
//                     .Label =  "i1_nc_l1",
//                     .Detail = undefined("(property) i1.i1_nc_l1: () => void"),
//                 },
//                 &.{
//                     .Label =  "p1",
//                     .Detail = undefined("(property) i1.p1: number"),
//                 },
//                 &.{
//                     .Label =  "f1",
//                     .Detail = undefined("(method) i1.f1(): void"),
//                 },
//                 &.{
//                     .Label =  "l1",
//                     .Detail = undefined("(property) i1.l1: () => void"),
//                 },
//                 &.{
//                     .Label =  "nc_p1",
//                     .Detail = undefined("(property) i1.nc_p1: number"),
//                 },
//                 &.{
//                     .Label =  "nc_f1",
//                     .Detail = undefined("(method) i1.nc_f1(): void"),
//                 },
//                 &.{
//                     .Label =  "nc_l1",
//                     .Detail = undefined("(property) i1.nc_l1: () => void"),
//                 },
//             },
//         },
//     });
    _ = f.GoToMarker(undefined, "2");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "i1_f1"});
    _ = f.GoToMarker(undefined, "3");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    _ = f.GoToMarker(undefined, "4");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    _ = f.GoToMarker(undefined, "5");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    _ = f.GoToMarker(undefined, "l2");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    _ = f.GoToMarker(undefined, "l3");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    _ = f.GoToMarker(undefined, "l4");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    _ = f.GoToMarker(undefined, "l5");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    try f.VerifyQuickInfoAt(undefined, "1iq", "var i1_i: i1", "");
    try f.VerifyQuickInfoAt(undefined, "2q", "(method) i1.i1_f1(): void", "i1_f1");
    try f.VerifyQuickInfoAt(undefined, "3q", "(method) i1.i1_nc_f1(): void", "");
    try f.VerifyQuickInfoAt(undefined, "4q", "(method) i1.f1(): void", "");
    try f.VerifyQuickInfoAt(undefined, "5q", "(method) i1.nc_f1(): void", "");
    try f.VerifyQuickInfoAt(undefined, "l2q", "(property) i1.i1_l1: () => void", "i1_l1");
    try f.VerifyQuickInfoAt(undefined, "l3q", "(property) i1.i1_nc_l1: () => void", "");
    try f.VerifyQuickInfoAt(undefined, "l4q", "(property) i1.l1: () => void", "");
    try f.VerifyQuickInfoAt(undefined, "l5q", "(property) i1.nc_l1: () => void", "");
    // f.VerifyCompletions(undefined, "6", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "i1_p1",
//                     .Detail = undefined("(property) c1.i1_p1: number"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "i1_p1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "i1_f1",
//                     .Detail = undefined("(method) c1.i1_f1(): void"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "i1_f1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "i1_l1",
//                     .Detail = undefined("(property) c1.i1_l1: () => void"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "i1_l1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "i1_nc_p1",
//                     .Detail = undefined("(property) c1.i1_nc_p1: number"),
//                 },
//                 &.{
//                     .Label =  "i1_nc_f1",
//                     .Detail = undefined("(method) c1.i1_nc_f1(): void"),
//                 },
//                 &.{
//                     .Label =  "i1_nc_l1",
//                     .Detail = undefined("(property) c1.i1_nc_l1: () => void"),
//                 },
//                 &.{
//                     .Label =  "p1",
//                     .Detail = undefined("(property) c1.p1: number"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "c1_p1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "f1",
//                     .Detail = undefined("(method) c1.f1(): void"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "c1_f1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "l1",
//                     .Detail = undefined("(property) c1.l1: () => void"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "c1_l1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "nc_p1",
//                     .Detail = undefined("(property) c1.nc_p1: number"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "c1_nc_p1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "nc_f1",
//                     .Detail = undefined("(method) c1.nc_f1(): void"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "c1_nc_f1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "nc_l1",
//                     .Detail = undefined("(property) c1.nc_l1: () => void"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "c1_nc_l1",
//                         },
//                     },
//                 },
//             },
//         },
//     });
    _ = f.GoToMarker(undefined, "7");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "i1_f1"});
    _ = f.GoToMarker(undefined, "9");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "c1_f1"});
    _ = f.GoToMarker(undefined, "10");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "c1_nc_f1"});
    _ = f.GoToMarker(undefined, "l9");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "c1_l1"});
    _ = f.GoToMarker(undefined, "l10");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "c1_nc_l1"});
    _ = f.GoToMarker(undefined, "8");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    _ = f.GoToMarker(undefined, "l7");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    _ = f.GoToMarker(undefined, "l8");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    try f.VerifyQuickInfoAt(undefined, "6iq", "var c1_i: c1", "");
    try f.VerifyQuickInfoAt(undefined, "7q", "(method) c1.i1_f1(): void", "i1_f1");
    try f.VerifyQuickInfoAt(undefined, "8q", "(method) c1.i1_nc_f1(): void", "");
    try f.VerifyQuickInfoAt(undefined, "9q", "(method) c1.f1(): void", "c1_f1");
    try f.VerifyQuickInfoAt(undefined, "10q", "(method) c1.nc_f1(): void", "c1_nc_f1");
    try f.VerifyQuickInfoAt(undefined, "l7q", "(property) c1.i1_l1: () => void", "i1_l1");
    try f.VerifyQuickInfoAt(undefined, "l8q", "(property) c1.i1_nc_l1: () => void", "");
    try f.VerifyQuickInfoAt(undefined, "l9q", "(property) c1.l1: () => void", "c1_l1");
    try f.VerifyQuickInfoAt(undefined, "l10q", "(property) c1.nc_l1: () => void", "c1_nc_l1");
    // f.VerifyCompletions(undefined, "11", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "i1_p1",
//                     .Detail = undefined("(property) i1.i1_p1: number"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "i1_p1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "i1_f1",
//                     .Detail = undefined("(method) i1.i1_f1(): void"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "i1_f1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "i1_l1",
//                     .Detail = undefined("(property) i1.i1_l1: () => void"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "i1_l1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "i1_nc_p1",
//                     .Detail = undefined("(property) i1.i1_nc_p1: number"),
//                 },
//                 &.{
//                     .Label =  "i1_nc_f1",
//                     .Detail = undefined("(method) i1.i1_nc_f1(): void"),
//                 },
//                 &.{
//                     .Label =  "i1_nc_l1",
//                     .Detail = undefined("(property) i1.i1_nc_l1: () => void"),
//                 },
//                 &.{
//                     .Label =  "p1",
//                     .Detail = undefined("(property) i1.p1: number"),
//                 },
//                 &.{
//                     .Label =  "f1",
//                     .Detail = undefined("(method) i1.f1(): void"),
//                 },
//                 &.{
//                     .Label =  "l1",
//                     .Detail = undefined("(property) i1.l1: () => void"),
//                 },
//                 &.{
//                     .Label =  "nc_p1",
//                     .Detail = undefined("(property) i1.nc_p1: number"),
//                 },
//                 &.{
//                     .Label =  "nc_f1",
//                     .Detail = undefined("(method) i1.nc_f1(): void"),
//                 },
//                 &.{
//                     .Label =  "nc_l1",
//                     .Detail = undefined("(property) i1.nc_l1: () => void"),
//                 },
//             },
//         },
//     });
    _ = f.GoToMarker(undefined, "12");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "i1_f1"});
    _ = f.GoToMarker(undefined, "13");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    _ = f.GoToMarker(undefined, "14");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    _ = f.GoToMarker(undefined, "15");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    _ = f.GoToMarker(undefined, "l12");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    _ = f.GoToMarker(undefined, "l13");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    _ = f.GoToMarker(undefined, "l14");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    _ = f.GoToMarker(undefined, "l15");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    try f.VerifyQuickInfoAt(undefined, "12q", "(method) i1.i1_f1(): void", "i1_f1");
    try f.VerifyQuickInfoAt(undefined, "13q", "(method) i1.i1_nc_f1(): void", "");
    try f.VerifyQuickInfoAt(undefined, "14q", "(method) i1.f1(): void", "");
    try f.VerifyQuickInfoAt(undefined, "15q", "(method) i1.nc_f1(): void", "");
    try f.VerifyQuickInfoAt(undefined, "l12q", "(property) i1.i1_l1: () => void", "i1_l1");
    try f.VerifyQuickInfoAt(undefined, "l13q", "(property) i1.i1_nc_l1: () => void", "");
    try f.VerifyQuickInfoAt(undefined, "l14q", "(property) i1.l1: () => void", "");
    try f.VerifyQuickInfoAt(undefined, "l15q", "(property) i1.nc_l1: () => void", "");
    // f.VerifyCompletions(undefined, "16", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "i1_i",
//                     .Detail = undefined("var i1_i: i1"),
//                 },
//                 &.{
//                     .Label =  "c1",
//                     .Detail = undefined("class c1"),
//                 },
//                 &.{
//                     .Label =  "c1_i",
//                     .Detail = undefined("var c1_i: c1"),
//                 },
//             },
//             .Excludes = &.{
//                 "i1",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "16i", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "i1",
//                     .Detail = undefined("interface i1"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "i1 is interface with properties",
//                         },
//                     },
//                 },
//             },
//         },
//     });
    try f.VerifyQuickInfoAt(undefined, "17iq", "var c2_i: c2", "");
    try f.VerifyQuickInfoAt(undefined, "18iq", "var c3_i: c3", "");
    _ = f.GoToMarker(undefined, "17");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "c2 constructor"});
    _ = f.GoToMarker(undefined, "18");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    try f.VerifyQuickInfoAt(undefined, "18sq", "constructor c2(a: number): c2", "c2 constructor");
    try f.VerifyQuickInfoAt(undefined, "18spropq", "class c2", "");
    try f.VerifyQuickInfoAt(undefined, "18spropProp", "(property) c2.c2_p1: number", "c2 c2_p1");
    try f.VerifyQuickInfoAt(undefined, "17q", "constructor c2(a: number): c2", "c2 constructor");
    try f.VerifyQuickInfoAt(undefined, "18q", "constructor c3(): c3", "");
    // f.VerifyCompletions(undefined, &.{"19", "29"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "c2_p1",
//                     .Detail = undefined("(property) c2.c2_p1: number"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "c2 c2_p1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "c2_f1",
//                     .Detail = undefined("(method) c2.c2_f1(): void"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "c2 c2_f1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "c2_prop",
//                     .Detail = undefined("(property) c2.c2_prop: number"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "c2 c2_prop",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "c2_nc_p1",
//                     .Detail = undefined("(property) c2.c2_nc_p1: number"),
//                 },
//                 &.{
//                     .Label =  "c2_nc_f1",
//                     .Detail = undefined("(method) c2.c2_nc_f1(): void"),
//                 },
//                 &.{
//                     .Label =  "c2_nc_prop",
//                     .Detail = undefined("(property) c2.c2_nc_prop: number"),
//                 },
//                 &.{
//                     .Label =  "p1",
//                     .Detail = undefined("(property) c2.p1: number"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "c2 p1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "f1",
//                     .Detail = undefined("(method) c2.f1(): void"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "c2 f1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "prop",
//                     .Detail = undefined("(property) c2.prop: number"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "c2 prop",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "nc_p1",
//                     .Detail = undefined("(property) c2.nc_p1: number"),
//                 },
//                 &.{
//                     .Label =  "nc_f1",
//                     .Detail = undefined("(method) c2.nc_f1(): void"),
//                 },
//                 &.{
//                     .Label =  "nc_prop",
//                     .Detail = undefined("(property) c2.nc_prop: number"),
//                 },
//             },
//         },
//     });
    _ = f.GoToMarker(undefined, "20");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "c2 c2_f1"});
    _ = f.GoToMarker(undefined, "22");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "c2 f1"});
    _ = f.GoToMarker(undefined, "21");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    _ = f.GoToMarker(undefined, "23");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    try f.VerifyQuickInfoAt(undefined, "20q", "(method) c2.c2_f1(): void", "c2 c2_f1");
    try f.VerifyQuickInfoAt(undefined, "21q", "(method) c2.c2_nc_f1(): void", "");
    try f.VerifyQuickInfoAt(undefined, "22q", "(method) c2.f1(): void", "c2 f1");
    try f.VerifyQuickInfoAt(undefined, "23q", "(method) c2.nc_f1(): void", "");
    // f.VerifyCompletions(undefined, "24", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "c2_p1",
//                     .Detail = undefined("(property) c2.c2_p1: number"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "c2 c2_p1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "c2_f1",
//                     .Detail = undefined("(method) c2.c2_f1(): void"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "c2 c2_f1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "c2_prop",
//                     .Detail = undefined("(property) c2.c2_prop: number"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "c2 c2_prop",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "c2_nc_p1",
//                     .Detail = undefined("(property) c2.c2_nc_p1: number"),
//                 },
//                 &.{
//                     .Label =  "c2_nc_f1",
//                     .Detail = undefined("(method) c2.c2_nc_f1(): void"),
//                 },
//                 &.{
//                     .Label =  "c2_nc_prop",
//                     .Detail = undefined("(property) c2.c2_nc_prop: number"),
//                 },
//                 &.{
//                     .Label =  "p1",
//                     .Detail = undefined("(property) c3.p1: number"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "c3 p1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "f1",
//                     .Detail = undefined("(method) c3.f1(): void"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "c3 f1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "prop",
//                     .Detail = undefined("(property) c3.prop: number"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "c3 prop",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "nc_p1",
//                     .Detail = undefined("(property) c3.nc_p1: number"),
//                 },
//                 &.{
//                     .Label =  "nc_f1",
//                     .Detail = undefined("(method) c3.nc_f1(): void"),
//                 },
//                 &.{
//                     .Label =  "nc_prop",
//                     .Detail = undefined("(property) c3.nc_prop: number"),
//                 },
//             },
//         },
//     });
    _ = f.GoToMarker(undefined, "25");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "c2 c2_f1"});
    _ = f.GoToMarker(undefined, "27");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "c3 f1"});
    _ = f.GoToMarker(undefined, "26");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    _ = f.GoToMarker(undefined, "28");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    try f.VerifyQuickInfoAt(undefined, "25q", "(method) c2.c2_f1(): void", "c2 c2_f1");
    try f.VerifyQuickInfoAt(undefined, "26q", "(method) c2.c2_nc_f1(): void", "");
    try f.VerifyQuickInfoAt(undefined, "27q", "(method) c3.f1(): void", "c3 f1");
    try f.VerifyQuickInfoAt(undefined, "28q", "(method) c3.nc_f1(): void", "");
    _ = f.GoToMarker(undefined, "30");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "c2 c2_f1"});
    _ = f.GoToMarker(undefined, "32");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "c2 f1"});
    _ = f.GoToMarker(undefined, "31");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    _ = f.GoToMarker(undefined, "33");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    try f.VerifyQuickInfoAt(undefined, "30q", "(method) c2.c2_f1(): void", "c2 c2_f1");
    try f.VerifyQuickInfoAt(undefined, "31q", "(method) c2.c2_nc_f1(): void", "");
    try f.VerifyQuickInfoAt(undefined, "32q", "(method) c2.f1(): void", "c2 f1");
    try f.VerifyQuickInfoAt(undefined, "33q", "(method) c2.nc_f1(): void", "");
    _ = f.GoToMarker(undefined, "34");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "c2 constructor"});
    try f.VerifyQuickInfoAt(undefined, "34iq", "var c4_i: c4", "");
    try f.VerifyQuickInfoAt(undefined, "34q", "constructor c4(a: number): c4", "c2 constructor");
    // f.VerifyCompletions(undefined, "35", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "c2",
//                     .Detail = undefined("class c2"),
//                 },
//                 &.{
//                     .Label =  "c2_i",
//                     .Detail = undefined("var c2_i: c2"),
//                 },
//                 &.{
//                     .Label =  "c3",
//                     .Detail = undefined("class c3"),
//                 },
//                 &.{
//                     .Label =  "c3_i",
//                     .Detail = undefined("var c3_i: c3"),
//                 },
//                 &.{
//                     .Label =  "c4",
//                     .Detail = undefined("class c4"),
//                 },
//                 &.{
//                     .Label =  "c4_i",
//                     .Detail = undefined("var c4_i: c4"),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"36", "46"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "i2_p1",
//                     .Detail = undefined("(property) i2.i2_p1: number"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "i2_p1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "i2_f1",
//                     .Detail = undefined("(method) i2.i2_f1(): void"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "i2_f1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "i2_l1",
//                     .Detail = undefined("(property) i2.i2_l1: () => void"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "i2_l1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "i2_nc_p1",
//                     .Detail = undefined("(property) i2.i2_nc_p1: number"),
//                 },
//                 &.{
//                     .Label =  "i2_nc_f1",
//                     .Detail = undefined("(method) i2.i2_nc_f1(): void"),
//                 },
//                 &.{
//                     .Label =  "i2_nc_l1",
//                     .Detail = undefined("(property) i2.i2_nc_l1: () => void"),
//                 },
//                 &.{
//                     .Label =  "p1",
//                     .Detail = undefined("(property) i2.p1: number"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "i2 p1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "f1",
//                     .Detail = undefined("(method) i2.f1(): void"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "i2 f1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "l1",
//                     .Detail = undefined("(property) i2.l1: () => void"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "i2 l1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "nc_p1",
//                     .Detail = undefined("(property) i2.nc_p1: number"),
//                 },
//                 &.{
//                     .Label =  "nc_f1",
//                     .Detail = undefined("(method) i2.nc_f1(): void"),
//                 },
//                 &.{
//                     .Label =  "nc_l1",
//                     .Detail = undefined("(property) i2.nc_l1: () => void"),
//                 },
//             },
//         },
//     });
    _ = f.GoToMarker(undefined, "37");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "i2_f1"});
    _ = f.GoToMarker(undefined, "39");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "i2 f1"});
    _ = f.GoToMarker(undefined, "38");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    _ = f.GoToMarker(undefined, "40");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    _ = f.GoToMarker(undefined, "l37");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    _ = f.GoToMarker(undefined, "l37");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    _ = f.GoToMarker(undefined, "l39");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    _ = f.GoToMarker(undefined, "l40");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    try f.VerifyQuickInfoAt(undefined, "36iq", "var i2_i: i2", "");
    try f.VerifyQuickInfoAt(undefined, "37iq", "var i3_i: i3", "");
    try f.VerifyQuickInfoAt(undefined, "37q", "(method) i2.i2_f1(): void", "i2_f1");
    try f.VerifyQuickInfoAt(undefined, "38q", "(method) i2.i2_nc_f1(): void", "");
    try f.VerifyQuickInfoAt(undefined, "39q", "(method) i2.f1(): void", "i2 f1");
    try f.VerifyQuickInfoAt(undefined, "40q", "(method) i2.nc_f1(): void", "");
    try f.VerifyQuickInfoAt(undefined, "l37q", "(property) i2.i2_l1: () => void", "i2_l1");
    try f.VerifyQuickInfoAt(undefined, "l38q", "(property) i2.i2_nc_l1: () => void", "");
    try f.VerifyQuickInfoAt(undefined, "l39q", "(property) i2.l1: () => void", "i2 l1");
    try f.VerifyQuickInfoAt(undefined, "l40q", "(property) i2.nc_l1: () => void", "");
    // f.VerifyCompletions(undefined, "41", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "i2_p1",
//                     .Detail = undefined("(property) i2.i2_p1: number"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "i2_p1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "i2_f1",
//                     .Detail = undefined("(method) i2.i2_f1(): void"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "i2_f1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "i2_l1",
//                     .Detail = undefined("(property) i2.i2_l1: () => void"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "i2_l1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "i2_nc_p1",
//                     .Detail = undefined("(property) i2.i2_nc_p1: number"),
//                 },
//                 &.{
//                     .Label =  "i2_nc_f1",
//                     .Detail = undefined("(method) i2.i2_nc_f1(): void"),
//                 },
//                 &.{
//                     .Label =  "i2_nc_l1",
//                     .Detail = undefined("(property) i2.i2_nc_l1: () => void"),
//                 },
//                 &.{
//                     .Label =  "p1",
//                     .Detail = undefined("(property) i3.p1: number"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "i3 p1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "f1",
//                     .Detail = undefined("(method) i3.f1(): void"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "i3 f1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "l1",
//                     .Detail = undefined("(property) i3.l1: () => void"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "i3 l1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "nc_p1",
//                     .Detail = undefined("(property) i3.nc_p1: number"),
//                 },
//                 &.{
//                     .Label =  "nc_f1",
//                     .Detail = undefined("(method) i3.nc_f1(): void"),
//                 },
//                 &.{
//                     .Label =  "nc_l1",
//                     .Detail = undefined("(property) i3.nc_l1: () => void"),
//                 },
//             },
//         },
//     });
    _ = f.GoToMarker(undefined, "42");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "i2_f1"});
    _ = f.GoToMarker(undefined, "44");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "i3 f1"});
    _ = f.GoToMarker(undefined, "43");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    _ = f.GoToMarker(undefined, "45");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    _ = f.GoToMarker(undefined, "l42");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    _ = f.GoToMarker(undefined, "l43");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    _ = f.GoToMarker(undefined, "l44");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    _ = f.GoToMarker(undefined, "l45");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    try f.VerifyQuickInfoAt(undefined, "42q", "(method) i2.i2_f1(): void", "i2_f1");
    try f.VerifyQuickInfoAt(undefined, "43q", "(method) i2.i2_nc_f1(): void", "");
    try f.VerifyQuickInfoAt(undefined, "44q", "(method) i3.f1(): void", "i3 f1");
    try f.VerifyQuickInfoAt(undefined, "45q", "(method) i3.nc_f1(): void", "");
    try f.VerifyQuickInfoAt(undefined, "l42q", "(property) i2.i2_l1: () => void", "i2_l1");
    try f.VerifyQuickInfoAt(undefined, "l43q", "(property) i2.i2_nc_l1: () => void", "");
    try f.VerifyQuickInfoAt(undefined, "l44q", "(property) i3.l1: () => void", "i3 l1");
    try f.VerifyQuickInfoAt(undefined, "l45q", "(property) i3.nc_l1: () => void", "");
    // f.VerifyCompletions(undefined, "46", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "i2_p1",
//                     .Detail = undefined("(property) i2.i2_p1: number"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "i2_p1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "i2_f1",
//                     .Detail = undefined("(method) i2.i2_f1(): void"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "i2_f1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "i2_l1",
//                     .Detail = undefined("(property) i2.i2_l1: () => void"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "i2_l1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "i2_nc_p1",
//                     .Detail = undefined("(property) i2.i2_nc_p1: number"),
//                 },
//                 &.{
//                     .Label =  "i2_nc_f1",
//                     .Detail = undefined("(method) i2.i2_nc_f1(): void"),
//                 },
//                 &.{
//                     .Label =  "i2_nc_l1",
//                     .Detail = undefined("(property) i2.i2_nc_l1: () => void"),
//                 },
//                 &.{
//                     .Label =  "p1",
//                     .Detail = undefined("(property) i2.p1: number"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "i2 p1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "f1",
//                     .Detail = undefined("(method) i2.f1(): void"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "i2 f1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "l1",
//                     .Detail = undefined("(property) i2.l1: () => void"),
//                     .Documentation = &.{
//                         .MarkupContent = &.{
//                             .Kind =  lsproto.MarkupKindMarkdown,
//                             .Value = "i2 l1",
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =  "nc_p1",
//                     .Detail = undefined("(property) i2.nc_p1: number"),
//                 },
//                 &.{
//                     .Label =  "nc_f1",
//                     .Detail = undefined("(method) i2.nc_f1(): void"),
//                 },
//                 &.{
//                     .Label =  "nc_l1",
//                     .Detail = undefined("(property) i2.nc_l1: () => void"),
//                 },
//             },
//         },
//     });
    _ = f.GoToMarker(undefined, "47");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "i2_f1"});
    _ = f.GoToMarker(undefined, "49");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = "i2 f1"});
    _ = f.GoToMarker(undefined, "48");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    _ = f.GoToMarker(undefined, "l47");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    _ = f.GoToMarker(undefined, "l48");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    _ = f.GoToMarker(undefined, "l49");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    _ = f.GoToMarker(undefined, "l50");
    // try f.VerifySignatureHelp(undefined, .{.DocComment = ""});
    try f.VerifyQuickInfoAt(undefined, "47q", "(method) i2.i2_f1(): void", "i2_f1");
    try f.VerifyQuickInfoAt(undefined, "48q", "(method) i2.i2_nc_f1(): void", "");
    try f.VerifyQuickInfoAt(undefined, "49q", "(method) i2.f1(): void", "i2 f1");
    try f.VerifyQuickInfoAt(undefined, "50q", "(method) i2.nc_f1(): void", "");
    try f.VerifyQuickInfoAt(undefined, "l47q", "(property) i2.i2_l1: () => void", "i2_l1");
    try f.VerifyQuickInfoAt(undefined, "l48q", "(property) i2.i2_nc_l1: () => void", "");
    try f.VerifyQuickInfoAt(undefined, "l49q", "(property) i2.l1: () => void", "i2 l1");
    try f.VerifyQuickInfoAt(undefined, "l40q", "(property) i2.nc_l1: () => void", "");
    // f.VerifyCompletions(undefined, "51", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "i2_i",
//                     .Detail = undefined("var i2_i: i2"),
//                 },
//                 &.{
//                     .Label =  "i3_i",
//                     .Detail = undefined("var i3_i: i3"),
//                 },
//             },
//             .Excludes = &.{
//                 "i2",
//                 "i3",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "51i", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "i2",
//                     .Detail = undefined("interface i2"),
//                 },
//                 &.{
//                     .Label =  "i3",
//                     .Detail = undefined("interface i3"),
//                 },
//             },
//         },
//     });
    try f.VerifyQuickInfoAt(undefined, "52", "constructor c5(): c5", "c5 class");
    try f.VerifyQuickInfoAt(undefined, "53", "class c5", "c5 class");
    try f.VerifyQuickInfoAt(undefined, "54", "(property) c5.b: number", "");
    try f.VerifyQuickInfoAt(undefined, "55", "constructor c2(a: number): c2", "c2 constructor");
    try f.VerifyQuickInfoAt(undefined, "56", "constructor c3(): c3", "");
    try f.VerifyQuickInfoAt(undefined, "57", "constructor c6(): c6", "");
}

test "TestTsxSignatureHelp1" {
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
        \\function _buildMainButton({ onClick, children, className }: ButtonProps): JSX.Element {
        \\    return(<button className={className} onClick={onClick}>{ children || 'MAIN BUTTON'}</button>);
        \\}
        \\export function MainButton(props: ButtonProps): JSX.Element {
        \\    return this._buildMainButton(props);
        \\}
        \\let e1 = <MainButton/*1*/ /*2*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // try f.VerifySignatureHelp(undefined, .{.Text = "MainButton(props: ButtonProps): JSX.Element", .ParameterSpan = "props: ButtonProps"});
    _ = f.GoToMarker(undefined, "2");
    // try f.VerifySignatureHelp(undefined, .{.Text = "MainButton(props: ButtonProps): JSX.Element", .ParameterSpan = "props: ButtonProps"});
}

test "TestRenameExportSpecifier" {
    const content =
        \\// @Filename: a.ts
        \\const name = {};
        \\export { name as name/**/ };
        \\// @Filename: b.ts
        \\import { name } from './a';
        \\const x = name.toString();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, &.{.UseAliasesForRename = core.TSFalse}, "");
}

test "TestFormattingGlobalAugmentation1" {
    const content =
        \\/*1*/declare          global                      {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCurrentLineContent(undefined, "declare global {");
}

test "TestTsxCompletion8" {
    const content =
        \\//@Filename: file.tsx
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\        div: { ONE: string; TWO: number; }
        \\    }
        \\}
        \\var x = <div /*1*/ autoComplete /*2*/ />;
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
//                 "ONE",
//                 "TWO",
//             },
//         },
//     });
}

test "TestGetJavaScriptSyntacticDiagnostics1" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\import a = b;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineNonSuggestionDiagnostics(undefined);
}

test "TestOrganizeImports14" {
    const content =
        \\// @filename: /a.ts
        \\export const foo = 1;
        \\// @filename: /b.ts
        \\/**
        \\ * Module doc comment
        \\ *
        \\ * @module
        \\ */
        \\
        \\// comment 1
        \\
        \\// comment 2
        \\
        \\import { foo } from "./a";
        \\import { foo } from "./a";
        \\import { foo } from "./a";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/b.ts");
    // try f.VerifyOrganizeImports(undefined,
//         "/**\n * Module doc comment\n *\n * @module\n */\n\n// comment 1\n\n// comment 2\n\n",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
}

test "TestStringLiteralCompletionsForStringEnumContextualType" {
    const content =
        \\const enum E {
        \\    A = "A",
        \\}
        \\const e: E = "/**/";
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

test "TestInlayHintsInteractiveMultifile1" {
    const content =
        \\// @lib: es5
        \\// @Filename: /a.ts
        \\export interface Foo { a: string }
        \\// @Filename: /b.ts
        \\async function foo () {
        \\    return {} as any as import('./a').Foo
        \\}
        \\function bar () { return import('./a') }
        \\async function main () {
        \\    const a = await foo()
        \\    const b = await bar()
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/b.ts");
    // try f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayVariableTypeHints = core.TSTrue, .IncludeInlayFunctionLikeReturnTypeHints = core.TSTrue}});
}

test "TestCompletionListInTypeLiteralInTypeParameter1" {
    const content =
        \\interface Foo {
        \\    one: string;
        \\    two: number;
        \\    333: symbol;
        \\    '4four': boolean;
        \\    '5 five': object;
        \\    number: string;
        \\    Object: number;
        \\}
        \\
        \\interface Bar<T extends Foo> {
        \\    foo: T;
        \\}
        \\
        \\var foobar: Bar<{/**/
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
//             .Unsorted = &.{
//                 "one",
//                 "two",
//                 "\"333\"",
//                 "\"4four\"",
//                 "\"5 five\"",
//                 "number",
//                 "Object",
//             },
//         },
//     });
}

test "TestJsxAttributeCompletionStyleDefault" {
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

test "TestRenameDestructuringAssignmentNestedInFor" {
    const content =
        \\interface MultiRobot {
        \\    name: string;
        \\    skills: {
        \\        [|[|{| "contextRangeIndex": 0 |}primary|]: string;|]
        \\        secondary: string;
        \\    };
        \\}
        \\declare let multiRobot: MultiRobot, [|[|{| "contextRangeIndex": 2 |}primary|]: string|], secondary: string, primaryA: string, secondaryA: string, i: number;
        \\for ([|{ skills: { [|{| "contextRangeIndex": 4 |}primary|]: primaryA, secondary: secondaryA } } = multiRobot|], i = 0; i < 1; i++) {
        \\    primaryA;
        \\}
        \\for ([|{ skills: { [|{| "contextRangeIndex": 6 |}primary|], secondary } } = multiRobot|], i = 0; i < 1; i++) {
        \\    [|primary|];
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyNoErrors(undefined);
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[1], f.Ranges()[5], f.Ranges()[3], f.Ranges()[7], f.Ranges()[8]);
}

test "TestOrganizeImportsType9" {
    const content =
        \\import { type a, type A, b, B } from "foo";
        \\console.log(a, b, A, B);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyOrganizeImports(undefined,
//         "import { type a, type A, b, B } from \"foo\";\nconsole.log(a, b, A, B);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSUnknown,
//             .OrganizeImportsTypeOrder =  lsutil.OrganizeImportsTypeOrderInline,
//         },
//     );
    _ = f.ReplaceLine(undefined, 0, "import { type a, type A, b, B } from \"foo1\";");
    // try f.VerifyOrganizeImports(undefined,
//         "import { type a, type A, b, B } from \"foo1\";\nconsole.log(a, b, A, B);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSUnknown,
//             .OrganizeImportsTypeOrder =  lsutil.OrganizeImportsTypeOrderFirst,
//         },
//     );
    _ = f.ReplaceLine(undefined, 0, "import { type a, type A, b, B } from \"foo2\";");
    // try f.VerifyOrganizeImports(undefined,
//         "import { b, B, type a, type A } from \"foo2\";\nconsole.log(a, b, A, B);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSUnknown,
//             .OrganizeImportsTypeOrder =  lsutil.OrganizeImportsTypeOrderLast,
//         },
//     );
    _ = f.ReplaceLine(undefined, 0, "import { type a, type A, b, B } from \"foo3\";");
    // try f.VerifyOrganizeImports(undefined,
//         "import { type a, type A, b, B } from \"foo3\";\nconsole.log(a, b, A, B);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSUnknown,
//         },
//     );
    _ = f.ReplaceLine(undefined, 0, "import { type a, type A, b, B } from \"foo4\";");
    // try f.VerifyOrganizeImports(undefined,
//         "import { type a, type A, b, B } from \"foo4\";\nconsole.log(a, b, A, B);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSTrue,
//         },
//     );
    _ = f.ReplaceLine(undefined, 0, "import { type a, type A, b, B } from \"foo5\";");
    // try f.VerifyOrganizeImports(undefined,
//         "import { type A, B, type a, b } from \"foo5\";\nconsole.log(a, b, A, B);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSFalse,
//         },
//     );
}

test "TestSmartSelection_imports" {
    const content =
        \\import { /**/x as y, z } from './z';
        \\import { b } from './';
        \\
        \\console.log(1);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSelectionRanges(undefined);
}

test "TestSignatureHelpExpandedRestTuplesLocalLabels1" {
    const content =
        \\interface AppleInfo {
        \\  color: "green" | "red";
        \\}
        \\
        \\interface BananaInfo {
        \\  curvature: number;
        \\}
        \\
        \\type FruitAndInfo1 = ["apple", AppleInfo] | ["banana", BananaInfo];
        \\
        \\function logFruitTuple1(...[fruit, info]: FruitAndInfo1) {}
        \\logFruitTuple1(/*1*/);
        \\
        \\function logFruitTuple2(...[, info]: FruitAndInfo1) {}
        \\logFruitTuple2(/*2*/);
        \\logFruitTuple2("apple", /*3*/);
        \\
        \\function logFruitTuple3(...[fruit, ...rest]: FruitAndInfo1) {}
        \\logFruitTuple3(/*4*/);
        \\logFruitTuple3("apple", /*5*/);
        \\function logFruitTuple4(...[fruit, ...[info]]: FruitAndInfo1) {}
        \\logFruitTuple4(/*6*/);
        \\logFruitTuple4("apple", /*7*/);
        \\
        \\type FruitAndInfo2 = ["apple", ...AppleInfo[]] | ["banana", ...BananaInfo[]];
        \\
        \\function logFruitTuple5(...[fruit, firstInfo]: FruitAndInfo2) {}
        \\logFruitTuple5(/*8*/);
        \\logFruitTuple5("apple", /*9*/);
        \\
        \\function logFruitTuple6(...[fruit, ...fruitInfo]: FruitAndInfo2) {}
        \\logFruitTuple6(/*10*/);
        \\logFruitTuple6("apple", /*11*/);
        \\
        \\type FruitAndInfo3 = ["apple", ...AppleInfo[], number] | ["banana", ...BananaInfo[], number];
        \\
        \\function logFruitTuple7(...[fruit, fruitInfoOrNumber, secondFruitInfoOrNumber]: FruitAndInfo3) {}
        \\logFruitTuple7(/*12*/);
        \\logFruitTuple7("apple", /*13*/);
        \\logFruitTuple7("apple", { color: "red" }, /*14*/);
        \\
        \\function logFruitTuple8(...[fruit, , secondFruitInfoOrNumber]: FruitAndInfo3) {}
        \\logFruitTuple8(/*15*/);
        \\logFruitTuple8("apple", /*16*/);
        \\logFruitTuple8("apple", { color: "red" }, /*17*/);
        \\
        \\function logFruitTuple9(...[...[fruit, fruitInfoOrNumber, secondFruitInfoOrNumber]]: FruitAndInfo3) {}
        \\logFruitTuple9(/*18*/);
        \\logFruitTuple9("apple", /*19*/);
        \\logFruitTuple9("apple", { color: "red" }, /*20*/);
        \\
        \\function logFruitTuple10(...[fruit, {}, secondFruitInfoOrNumber]: FruitAndInfo3) {}
        \\logFruitTuple10(/*21*/);
        \\logFruitTuple10("apple", /*22*/);
        \\logFruitTuple10("apple", { color: "red" }, /*23*/);
        \\
        \\function logFruitTuple11(...{}: FruitAndInfo3) {}
        \\logFruitTuple11(/*24*/);
        \\logFruitTuple11("apple", /*25*/);
        \\logFruitTuple11("apple", { color: "red" }, /*26*/);
        \\function withPair(...[first, second]: [number, named: string]) {}
        \\withPair(/*27*/);
        \\withPair(101, /*28*/);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSignatureHelp(undefined);
}

test "TestFindAllRefsEnumAsNamespace" {
    const content =
        \\/*1*/enum /*2*/E { A }
        \\let e: /*3*/E.A;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestTsxIncremental" {
    const content =
        \\/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, "<");
    _ = f.Insert(undefined, "div");
    _ = f.Insert(undefined, " ");
    _ = f.Insert(undefined, " id");
    _ = f.Insert(undefined, "=");
    _ = f.Insert(undefined, "\"foo");
    _ = f.Insert(undefined, "\"");
    _ = f.Insert(undefined, ">");
}

test "TestJsDocPropertyDescription9" {
    const content =
        \\class LiteralClass {
        \\    /** Something generic */
        \\    static [key: `prefix${string}`]: any;
        \\    /** Something else */
        \\    static [key: `prefix${number}`]: number;
        \\}
        \\function literalClass(e: typeof LiteralClass) {
        \\    console.log(e./*literal1Class*/prefixMember); 
        \\    console.log(e./*literal2Class*/anything);
        \\    console.log(e./*literal3Class*/prefix0);
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyQuickInfoAt(undefined, "literal1Class", "(index) LiteralClass[`prefix${string}`]: any", "Something generic") catch {};
    _ = f.VerifyQuickInfoAt(undefined, "literal2Class", "any", "") catch {};
    _ = f.VerifyQuickInfoAt(undefined, "literal3Class", "(index) LiteralClass[`prefix${string}` | `prefix${number}`]: any", "Something generic\nSomething else") catch {};
}

test "TestRestParamsContextuallyTyped" {
    const content =
        \\var foo: Function = function (/*1*/a, /*2*/b, /*3*/c) { };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "(parameter) a: any", "");
    try f.VerifyQuickInfoAt(undefined, "2", "(parameter) b: any", "");
    try f.VerifyQuickInfoAt(undefined, "3", "(parameter) c: any", "");
}

test "TestFindReferencesJSXTagName" {
    const content =
        \\// @Filename: index.tsx
        \\import { /*1*/SubmissionComp } from "./RedditSubmission"
        \\function displaySubreddit(subreddit: string) {
        \\    let components = submissions
        \\        .map((value, index) => <SubmissionComp key={ index } elementPosition= { index } {...value.data} />);
        \\}
        \\// @Filename: RedditSubmission.ts
        \\export const /*2*/SubmissionComp = (submission: SubmissionProps) =>
        \\    <div style={{ fontFamily: "sans-serif" }}></div>;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestCodeFixClassImplementInterfaceComputedPropertyNameWellKnownSymbols" {
    const content =
        \\// @strict: false
        \\// @lib: es2017
        \\interface I<Species> {
        \\    [Symbol.hasInstance](o: any): boolean;
        \\    [Symbol.isConcatSpreadable]: boolean;
        \\    [Symbol.iterator](): any;
        \\    [Symbol.match]: boolean;
        \\    [Symbol.replace](...args);
        \\    [Symbol.search](str: string): number;
        \\    [Symbol.species](): Species;
        \\    [Symbol.split](str: string, limit?: number): string[];
        \\    [Symbol.toPrimitive](hint: "number"): number;
        \\    [Symbol.toPrimitive](hint: "default"): number;
        \\    [Symbol.toPrimitive](hint: "string"): string;
        \\    [Symbol.toStringTag]: string;
        \\    [Symbol.unscopables]: any;
        \\}
        \\class C implements I<number> {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'I<number>'",
        .NewFileContent = "interface I<Species> {\n    [Symbol.hasInstance](o: any): boolean;\n    [Symbol.isConcatSpreadable]: boolean;\n    [Symbol.iterator](): any;\n    [Symbol.match]: boolean;\n    [Symbol.replace](...args);\n    [Symbol.search](str: string): number;\n    [Symbol.species](): Species;\n    [Symbol.split](str: string, limit?: number): string[];\n    [Symbol.toPrimitive](hint: \"number\"): number;\n    [Symbol.toPrimitive](hint: \"default\"): number;\n    [Symbol.toPrimitive](hint: \"string\"): string;\n    [Symbol.toStringTag]: string;\n    [Symbol.unscopables]: any;\n}\nclass C implements I<number> {\n    [Symbol.hasInstance](o: any): boolean {\n        throw new Error(\"Method not implemented.\");\n    }\n    [Symbol.isConcatSpreadable]: boolean;\n    [Symbol.iterator]() {\n        throw new Error(\"Method not implemented.\");\n    }\n    [Symbol.match]: boolean;\n    [Symbol.replace](...args: any[]) {\n        throw new Error(\"Method not implemented.\");\n    }\n    [Symbol.search](str: string): number {\n        throw new Error(\"Method not implemented.\");\n    }\n    [Symbol.species](): number {\n        throw new Error(\"Method not implemented.\");\n    }\n    [Symbol.split](str: string, limit?: number): string[] {\n        throw new Error(\"Method not implemented.\");\n    }\n    [Symbol.toPrimitive](hint: \"number\"): number;\n    [Symbol.toPrimitive](hint: \"default\"): number;\n    [Symbol.toPrimitive](hint: \"string\"): string;\n    [Symbol.toPrimitive](hint: unknown): string | number {\n        throw new Error(\"Method not implemented.\");\n    }\n    [Symbol.toStringTag]: string;\n    [Symbol.unscopables]: any;\n}",
        .Index = 0,
    });
}

test "TestCompletionForStringLiteralNonrelativeImport3" {
    const content =
        \\// @allowJs: true
        \\// @Filename: tests/test0.ts
        \\import * as foo1 from "fake-module//*import_as0*/
        \\import foo2 = require("fake-module//*import_equals0*/
        \\var foo3 = require("fake-module//*require0*/
        \\// @Filename: package.json
        \\{ "dependencies": { "fake-module": "latest" } }
        \\// @Filename: node_modules/fake-module/ts.ts
        \\/*ts*/
        \\// @Filename: node_modules/fake-module/tsx.tsx
        \\/*tsx*/
        \\// @Filename: node_modules/fake-module/dts.d.ts
        \\/*dts*/
        \\// @Filename: node_modules/fake-module/js.js
        \\/*js*/
        \\// @Filename: node_modules/fake-module/jsx.jsx
        \\/*jsx*/
        \\// @Filename: node_modules/fake-module/repeated.js
        \\/*repeatedjs*/
        \\// @Filename: node_modules/fake-module/repeated.jsx
        \\/*repeatedjsx*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"import_as0", "import_equals0", "require0"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "dts",
//                 "js",
//                 "jsx",
//                 "repeated",
//                 "ts",
//                 "tsx",
//             },
//         },
//     });
}

test "TestSquiggleIllegalClassExtension" {
    const content =
        \\class Foo extends /*1*/Bar/*2*/ { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyErrorExistsBetweenMarkers(undefined, "1", "2");
    try f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
}

test "TestJsDocSee3" {
    const content =
        \\function foo ([|/*def1*/a|]: string) {
        \\    /**
        \\     * @see {/*use1*/[|a|]}
        \\     */
        \\    function bar ([|/*def2*/a|]: string) {
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, false, "use1");
}

test "TestUnusedClassInNamespace1" {
    const content =
        \\// @noUnusedLocals: true
        \\[| namespace greeter {
        \\  class class1 {
        \\  }
        \\} |]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyRangeAfterCodeFix(undefined, "namespace greeter {\n}", false, 0, 0);
}

test "TestOrganizeImports23" {
    const content =
        \\import {abc, Abc, type bc, type Bc} from 'b';
        \\import {
        \\  I,
        \\  R,
        \\  M,
        \\} from 'a';
        \\type x = bc | Bc;
        \\console.log(abc, Abc, I, R, M);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyOrganizeImports(undefined,
//         "import {\n    I,\n    M,\n    R,\n} from 'a';\nimport { abc, Abc, type bc, type Bc } from 'b';\ntype x = bc | Bc;\nconsole.log(abc, Abc, I, R, M);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
    // try f.VerifyOrganizeImports(undefined,
//         "import {\n    I,\n    M,\n    R,\n} from 'a';\nimport { abc, Abc, type bc, type Bc } from 'b';\ntype x = bc | Bc;\nconsole.log(abc, Abc, I, R, M);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
}

test "TestCompletionListEnumMembers" {
    const content =
        \\enum Foo {
        \\    bar,
        \\    baz
        \\}
        \\
        \\var v = Foo./*valueReference*/ba;
        \\var t :Foo./*typeReference*/ba;
        \\Foo.bar./*enumValueReference*/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"valueReference", "typeReference"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "bar",
//                 "baz",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "enumValueReference", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Unsorted = &.{
//                 "toString",
//                 "toFixed",
//                 "toExponential",
//                 "toPrecision",
//                 "valueOf",
//                 "toLocaleString",
//             },
//         },
//     });
}

test "TestCodeFixMissingTypeAnnotationOnExports23_heritage_formatting" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\function mixin<T extends new (...a: any) => any>(ctor: T): T {
        \\    return ctor;
        \\}
        \\class Point2D { x = 0; y = 0; }
        \\interface I{}
        \\export class Point3D extends
        \\    /** Base class */
        \\    mixin(Point2D)
        \\    // Test
        \\    implements I
        \\    {
        \\              z = 0;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFixAvailable(undefined, &.{"Extract base class to variable"});
    try f.VerifyCodeFix(undefined, .{
        .Description = "Extract base class to variable",
        .NewFileContent = "function mixin<T extends new (...a: any) => any>(ctor: T): T {\n    return ctor;\n}\nclass Point2D { x = 0; y = 0; }\ninterface I{}\nconst Point3DBase: typeof Point2D =\n    /** Base class */\n    mixin(Point2D);\nexport class Point3D extends Point3DBase\n    // Test\n    implements I\n    {\n              z = 0;\n}",
        .Index = 0,
    });
}

