const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestReferencesForAmbients" {
    const content =
        \\/*1*/declare module "/*2*/foo" {
        \\    /*3*/var /*4*/f: number;
        \\}
        \\
        \\/*5*/declare module "/*6*/bar" {
        \\    /*7*/export import /*8*/foo = require("/*9*/foo");
        \\    var f2: typeof /*10*/foo./*11*/f;
        \\}
        \\
        \\declare module "baz" {
        \\    /*12*/import bar = require("/*13*/bar");
        \\    var f2: typeof bar./*14*/foo;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14");
}

test "TestJsDocGenerics2" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: Foo.js
        \\/**
        \\ * @param {T[]} arr
        \\ * @param {(function(T):T)} valuator
        \\ * @template T
        \\ */
        \\function SortFilter(arr,valuator)
        \\{
        \\    return arr;
        \\}
        \\var a/*1*/ = SortFilter([0, 1, 2], q/*2*/ => q);
        \\var b/*3*/ = SortFilter([0, 1, 2], undefined);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "var a: number[]", "");
    // f.VerifyQuickInfoAt(undefined, "2", "(parameter) q: number", "");
    // f.VerifyQuickInfoAt(undefined, "3", "var b: number[]", "");
}

test "TestReferencesForMergedDeclarations3" {
    const content =
        \\[|class /*class*/[|testClass|] {
        \\    static staticMethod() { }
        \\    method() { }
        \\}|]
        \\
        \\[|module /*module*/[|testClass|] {
        \\    export interface Bar {
        \\
        \\    }
        \\}|]
        \\
        \\var c1: [|testClass|];
        \\var c2: [|testClass|].Bar;
        \\[|testClass|].staticMethod();
        \\[|testClass|].prototype.method();
        \\[|testClass|].bind(this);
        \\new [|testClass|]();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "module", "class");
}

test "TestFindAllReferencesNonExistentExportBinding" {
    const content =
        \\// @Filename: /tsconfig.json
        \\ { "compilerOptions": { "module": "commonjs" } }
        \\// @filename: /bar.ts
        \\import { Foo/**/ } from "./foo";
        \\// @filename: /foo.ts
        \\export { Foo }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "");
}

test "TestFindAllRefsRenameImportWithSameName" {
    const content =
        \\// @Filename: /a.ts
        \\[|export const /*0*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 0 |}x|] = 0;|]
        \\//@Filename: /b.ts
        \\[|import { /*1*/[|{| "contextRangeIndex": 2 |}x|] as /*2*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 2 |}x|] } from "./a";|]
        \\/*3*/[|x|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
    // f.VerifyBaselineFindAllReferences(undefined, "0", "1", "2", "3");
    // f.VerifyBaselineRename(undefined, null , f.Ranges()[1], f.Ranges()[3], f.Ranges()[4], f.Ranges()[5]);
}

test "TestImportNameCodeFix_symlink_own_package" {
    const content =
        \\// @Filename: /packages/b/b0.ts
        \\// @Symlink: /node_modules/b/b0.ts
        \\x;
        \\// @Filename: /packages/b/b1.ts
        \\// @Symlink: /node_modules/b/b1.ts
        \\import { a } from "a";
        \\export const x = 0;
        \\// @Filename: /packages/a/index.d.ts
        \\// @Symlink: /node_modules/a/index.d.ts
        \\export const a: number;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/packages/b/b0.ts");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { x } from \"./b1\";\n\nx;",
    }, null );
}

test "TestCompletionsOverridingMethod11" {
    const content =
        \\// @Filename: a.ts
        \\// @newline: LF
        \\function foo() {
        \\    const a = 1
        \\    const b = 2
        \\    foo()
        \\    return a + b
        \\}
        \\
        \\interface Base {
        \\    a: string
        \\    b(a: string): void
        \\    c(a: string): string
        \\    c(a: number): number
        \\}
        \\class Sub implements Base {
        \\   /*a*/
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
//                     .Label =      "a",
//                     .InsertText = undefined("a: string"),
//                     .FilterText = undefined("a"),
//                     .SortText =   undefined(string(ls.SortTextLocationPriority)),
//                 },
//                 &.{
//                     .Label =      "b",
//                     .InsertText = undefined("b(a: string): void {\n}"),
//                     .FilterText = undefined("b"),
//                     .SortText =   undefined(string(ls.SortTextLocationPriority)),
//                 },
//                 &.{
//                     .Label =      "c",
//                     .InsertText = undefined("c(a: string): string\nc(a: number): number\nc(a: unknown): string | number {\n}"),
//                     .FilterText = undefined("c"),
//                     .SortText =   undefined(string(ls.SortTextLocationPriority)),
//                 },
//             },
//         },
//     });
}

test "TestFormatNoSpaceBeforeCloseBrace2" {
    const content =
        \\new Foo(1,     );
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.VerifyCurrentFileContent(undefined, "new Foo(1,);");
}

test "TestCompletionListAtEndOfWordInArrowFunction03" {
    const content =
        \\(d, defaultIsAnInvalidParameterName) => default/*1*/
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
//                 "defaultIsAnInvalidParameterName",
//                 &.{
//                     .Label =    "default",
//                     .Detail =   undefined("default"),
//                     .Kind =     undefined(lsproto.CompletionItemKindKeyword),
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestQuickInfoUntypedModuleImport" {
    const content =
        \\// @strict: false
        \\// @Filename: node_modules/foo/index.js
        \\ /*index*/{}
        \\// @Filename: a.ts
        \\import /*foo*/foo from /*fooModule*/"foo";
        \\/*fooCall*/foo();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "a.ts");
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 0);
    _ = f.GoToMarker(undefined, "fooModule");
    _ = f.VerifyQuickInfoIs(undefined, "", "");
    _ = f.GoToMarker(undefined, "foo");
    _ = f.VerifyQuickInfoIs(undefined, "import foo", "");
    // f.VerifyBaselineFindAllReferences(undefined, "foo", "fooModule", "fooCall");
    // f.VerifyBaselineGoToDefinition(undefined, false, "fooModule", "foo");
}

test "TestGoToSource13_nodenext" {
    const content =
        \\// @Filename: /home/src/workspaces/project/node_modules/left-pad/package.json
        \\{
        \\  "name": "left-pad",
        \\  "version": "1.3.0",
        \\  "description": "String left pad",
        \\  "main": "index.js",
        \\  "types": "index.d.ts"
        \\}
        \\// @Filename: /home/src/workspaces/project/node_modules/left-pad/index.d.ts
        \\declare function leftPad(str: string|number, len: number, ch?: string|number): string;
        \\declare namespace leftPad { }
        \\export = leftPad;
        \\// @Filename: /home/src/workspaces/project/node_modules/left-pad/index.js
        \\module.exports = leftPad;
        \\function /*end*/leftPad(str, len, ch) {}
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\      "module": "node16",
        \\      "lib": ["es5"],
        \\      "strict": true,
        \\      "outDir": "./out",
        \\
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/index.mts
        \\import leftPad = require("left-pad");
        \\/*start*/leftPad("", 4);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.VerifyBaselineGoToSourceDefinition(undefined, "start");
}

test "TestGenericSignaturesAreProperlyCleaned" {
    const content =
        \\interface Int<T> {
        \\val<U>(f: (t: T) => U): Int<U>;
        \\}
        \\declare var v1: Int<string>;
        \\var v2: Int<number> = v1/*1*/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
    _ = f.GoToMarker(undefined, "1");
    _ = f.DeleteAtCaret(undefined, 1);
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
}

test "TestConstructorBraceFormatting" {
    const content =
        \\class X {
        \\    constructor () {}/*target*/
        \\ /**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, "}");
    _ = f.GoToMarker(undefined, "target");
    _ = f.VerifyCurrentLineContent(undefined, "    constructor() { }");
}

test "TestAutoImportFileExcludePatterns10" {
    const content =
        \\// @Filename: /src/vs/test.ts
        \\import { Parts } from './parts';
        \\export class /**/Extended implements Parts {
        \\}
        \\// @Filename: /src/vs/parts.ts
        \\import { Event } from '../event/event';
        \\
        \\export interface Parts {
        \\    readonly options: Event;
        \\}
        \\// @Filename: /src/event/event.ts
        \\export interface Event {
        \\    (): string;
        \\}
        \\// @Filename: /src/thing.ts
        \\import { Event } from './event/event';
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
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'Parts'",
        .NewFileContent = "import { Event } from '../event/event';\nimport { Parts } from './parts';\nexport class Extended implements Parts {\n    options: Event;\n}",
        .Index =           0,
        .UserPreferences = &.{.AutoImportFileExcludePatterns = &.{"src/thing.ts"}},
    });
}

test "TestGoToDefinitionOverriddenMember16" {
    const content =
        \\// @Filename: goToDefinitionOverrideJsdoc.ts
        \\// @allowJs: true
        \\// @checkJs: true
        \\export class C extends CompletelyUndefined {
        \\    /**
        \\     * @override/*1*/
        \\     * @returns {{}}
        \\     */
        \\    static foo() {
        \\        return {}
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestFindAllRefsPrimitiveJsDoc" {
    const content =
        \\// @noLib: true
        \\/**
        \\ * @param {/*1*/number} n
        \\ * @returns {/*2*/number}
        \\ */
        \\function f(n: /*3*/number): /*4*/number {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestCompletionAfterQuestionDot" {
    const content =
        \\// @strict: true
        \\class User {
        \\    #foo: User;
        \\    bar: User;
        \\    address?: {
        \\        city: string;
        \\        "postal code": string;
        \\    };
        \\    constructor() {
        \\        this.address[|?./*1*/|];
        \\        this[|?./*2*/|];
        \\        this?.bar[|?./*3*/|];
        \\    }
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
//                     .Label =  "city",
//                     .Detail = undefined("(property) city: string"),
//                 },
//                 &.{
//                     .Label =      "postal code",
//                     .InsertText = undefined("?.[\"postal code\"]"),
//                     .Detail =     undefined("(property) \"postal code\": string"),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "postal code",
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
//                 &.{
//                     .Label = "address",
//                 },
//                 &.{
//                     .Label = "bar",
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
//                     .Label = "address",
//                 },
//                 &.{
//                     .Label = "bar",
//                 },
//             },
//         },
//     });
}

test "TestReferencesForMergedDeclarations2" {
    const content =
        \\namespace ATest {
        \\    export interface Bar { }
        \\}
        \\
        \\function ATest() { }
        \\
        \\/*1*/import /*2*/alias = ATest; // definition
        \\
        \\var a: /*3*/alias.Bar; // namespace
        \\/*4*/alias.call(this); // value
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestSignatureHelpOnNestedOverloads" {
    const content =
        \\declare function fn(x: string);
        \\declare function fn(x: string, y: number);
        \\declare function fn2(x: string);
        \\declare function fn2(x: string, y: number);
        \\fn('', fn2(/*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // f.VerifySignatureHelp(undefined, .{.Text = "fn2(x: string): any", .ParameterName = "x", .ParameterSpan = "x: string", .OverloadsCount = 2});
    _ = f.Insert(undefined, "'',");
    // f.VerifySignatureHelp(undefined, .{.Text = "fn2(x: string, y: number): any", .ParameterName = "y", .ParameterSpan = "y: number", .OverloadsCount = 2});
}

test "TestGoToDefinitionPartialImplementation" {
    const content =
        \\// @Filename: goToDefinitionPartialImplementation_1.ts
        \\namespace A {
        \\    export interface /*Part1Definition*/IA {
        \\        y: string;
        \\    }
        \\}
        \\// @Filename: goToDefinitionPartialImplementation_2.ts
        \\namespace A {
        \\    export interface /*Part2Definition*/IA {
        \\        x: number;
        \\    }
        \\
        \\    var x: [|/*Part2Use*/IA|];
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "Part2Use");
}

test "TestCompletionListInObjectLiteralAssignmentPattern1" {
    const content =
        \\let x = { a: 1, b: 2 };
        \\let y = ({ /**/ } = x, 1);
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

test "TestFormatTsx" {
    const content =
        \\// @Filename: foo.tsx
        \\<div><p>'</p><p>{function(){return 1;}]}</p></div>
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.VerifyCurrentFileContent(undefined, "<div><p>'</p><p>{function() { return 1; }]}</p></div>");
}

test "TestSignatureHelpImplicitConstructor" {
    const content =
        \\class ImplicitConstructor {
        \\}
        \\var implicitConstructor = new ImplicitConstructor(/**/);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // f.VerifySignatureHelp(undefined, .{.Text = "ImplicitConstructor(): ImplicitConstructor", .ParameterCount = 0});
}

test "TestQuickInfoOnJsxIntrinsicDeclaredUsingCatchCallIndexSignature" {
    const content =
        \\// @jsx: react
        \\// @filename: /a.tsx
        \\declare namespace JSX {
        \\  interface IntrinsicElements { [elemName: string]: any; }
        \\}
        \\</**/div class="democlass" />;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestGetOccurrencesReturn4" {
    const content =
        \\function f(a: number) {
        \\    if (a > 0) {
        \\        return (function () {
        \\            return/*1*/;
        \\            return/*2*/;
        \\            return/*3*/;
        \\
        \\            if (false) {
        \\                return/*4*/ true;
        \\            }
        \\        })() || true;
        \\    }
        \\
        \\    var unusued = [1, 2, 3, 4].map(x => { return/*5*/ 4 })
        \\
        \\    return/*6*/;
        \\    return/*7*/ true;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Markers()));
}

test "TestImportSuggestionsCache_exportUndefined" {
    const content =
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{ "compilerOptions": { "module": "esnext", "lib": ["es5"] } }
        \\// @Filename: /home/src/workspaces/project/undefined.ts
        \\export = undefined;
        \\// @Filename: /home/src/workspaces/project/undefinedAlias.ts
        \\const x = undefined;
        \\export = x;
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\ /**/
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
//                     .Label =               "x",
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./undefinedAlias",
//                         },
//                     },
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =               "x",
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./undefinedAlias",
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestJsDocTypedefQuickInfo1" {
    const content =
        \\// @allowJs: true
        \\// @Filename: jsDocTypedef1.js
        \\/**
        \\ * @typedef {Object} Opts
        \\ * @property {string} x
        \\ * @property {string=} y
        \\ * @property {string} [z]
        \\ * @property {string} [w="hi"]
        \\ * 
        \\ * @param {Opts} opts
        \\ */
        \\function foo(/*1*/opts) {
        \\    opts.x;
        \\}
        \\foo({x: 'abc'});
        \\/**
        \\ * @typedef {object} Opts1
        \\ * @property {string} x
        \\ * @property {string=} y
        \\ * @property {string} [z]
        \\ * @property {string} [w="hi"]
        \\ * 
        \\ * @param {Opts1} opts
        \\ */
        \\function foo1(/*2*/opts1) {
        \\    opts1.x;
        \\}
        \\foo1({x: 'abc'});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestQuickInfoOnPropertyAccessInWriteLocation2" {
    const content =
        \\// @strict: true
        \\// @exactOptionalPropertyTypes: true
        \\declare const xx: { prop?: number };
        \\xx.prop/*1*/ += 1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "(property) prop?: number", "");
}

test "TestCompletionsImport_duplicatePackages_types" {
    const content =
        \\// @lib: es5
        \\// @module: commonjs
        \\// @esModuleInterop: true
        \\// @Filename: /node_modules/@types/react-dom/package.json
        \\{ "name": "react-dom", "version": "1.0.0", "types": "./index.d.ts" }
        \\// @Filename: /node_modules/@types/react-dom/index.d.ts
        \\import * as React from "react";
        \\export function render(): void;
        \\// @Filename: /node_modules/@types/react/package.json
        \\{ "name": "react", "version": "1.0.0", "types": "./index.d.ts" }
        \\// @Filename: /node_modules/@types/react/index.d.ts
        \\import "./other";
        \\export declare function useState(): void;
        \\// @Filename: /node_modules/@types/react/other.d.ts
        \\export declare function useRef(): void;
        \\// @Filename: /packages/a/node_modules/@types/react/package.json
        \\{ "name": "react", "version": "1.0.1", "types": "./index.d.ts" }
        \\// @Filename: /packages/a/node_modules/@types/react/index.d.ts
        \\export declare function useState(): void;
        \\// @Filename: /packages/a/index.ts
        \\import "react-dom";
        \\import "react";
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
//                                 .ModuleSpecifier = "react-dom",
//                             },
//                         },
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     },
//                     &.{
//                         .Label = "useState",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "react",
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

test "TestJsDocPropertyDescription12" {
    const content =
        \\type SymbolAlias = {
        \\    /** Something generic */
        \\    [p: symbol]: string;
        \\}
        \\function symbolAlias(e: SymbolAlias) {
        \\    console.log(e./*symbolAlias*/anything);
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "symbolAlias", "any", "");
}

test "TestExtendsKeywordCompletion2" {
    const content =
        \\function f1<T /*1*/>() {}
        \\function f2<T ext/*2*/>() {}
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
//                     .Label =    "extends",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestCompletionListInTypeLiteralInTypeParameter11" {
    const content =
        \\interface Foo {
        \\    one: string;
        \\    two: number;
        \\}
        \\interface Bar {
        \\    three: boolean;
        \\    four: symbol;
        \\}
        \\
        \\class A<T extends Foo> {}
        \\new A<{/*0*/}>();
        \\
        \\class B<T extends Foo, U extends Bar> {}
        \\new B<{/*1*/}, {/*2*/}>();
        \\
        \\declare const C: {
        \\   new <T extends Foo>(): unknown
        \\   new <T extends Bar>(): unknown
        \\}
        \\new C<{/*3*/}>()
        \\
        \\new (class <T extends Foo> {})<{/*4*/}>();
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
    // f.VerifyCompletions(undefined, "1", &.{
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
    // f.VerifyCompletions(undefined, "2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Unsorted = &.{
//                 "three",
//                 "four",
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
//             .Unsorted = &.{
//                 "one",
//                 "two",
//                 "three",
//                 "four",
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
//             .Unsorted = &.{
//                 "one",
//                 "two",
//             },
//         },
//     });
}

test "TestMemberListOfClass" {
    const content =
        \\class C1 {
        \\   public pubMeth() { }
        \\   private privMeth() { }
        \\   public pubProp = 0;
        \\   private privProp = 0;
        \\}
        \\var f = new C1();
        \\f./**/
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

test "TestGenericFunctionSignatureHelp1" {
    const content =
        \\function f<T>(a: T): T { return null; }
        \\f(/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // f.VerifySignatureHelp(undefined, .{.Text = "f(a: unknown): unknown"});
}

test "TestTabbingAfterNewlineInsertedBeforeWhile" {
    const content =
        \\function foo() {
        \\    /**/while (true) { }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.InsertLine(undefined, "");
    _ = f.VerifyCurrentLineContent(undefined, "    while (true) { }");
}

test "TestQuickInfoOnPropertyAccessInWriteLocation5" {
    const content =
        \\// @strict: true
        \\interface Serializer {
        \\  set value(v: string | number);
        \\  get value(): string;
        \\}
        \\declare let box: Serializer;
        \\box.value/*1*/ += 10;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "(property) Serializer.value: string | number", "");
}

test "TestCompletionListInNamedFunctionExpression" {
    const content =
        \\function foo(a: number): string {
        \\    /*insideFunctionDeclaration*/
        \\    return "";
        \\}
        \\
        \\(function foo(): number {
        \\    /*insideFunctionExpression*/
        \\    fo/*referenceInsideFunctionExpression*/o;
        \\    return "";
        \\})
        \\
        \\/*globalScope*/
        \\fo/*referenceInGlobalScope*/o;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"globalScope", "insideFunctionDeclaration", "insideFunctionExpression"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "foo",
//             },
//         },
//     });
    // f.VerifyQuickInfoAt(undefined, "referenceInsideFunctionExpression", "(local function) foo(): number", "");
    // f.VerifyQuickInfoAt(undefined, "referenceInGlobalScope", "function foo(a: number): string", "");
}

test "TestCompletionsJsxAttributeInitializer2" {
    const content =
        \\// @Filename: /a.tsx
        \\declare namespace JSX {
        \\    interface IntrinsicElements {
        \\        div: { a: string, b: string }
        \\    }
        \\}
        \\const foo = 0;
        \\<div x=[|f/*0*/|] />;
        \\
        \\<div a="1" b/*1*/ />
        \\<div a /*2*/ />
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
//                     .Label =      "foo",
//                     .InsertText = undefined("{foo}"),
//                     .Detail =     undefined("const foo: 0"),
//                     .Kind =       undefined(lsproto.CompletionItemKindVariable),
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
    // f.VerifyCompletions(undefined, &.{"1", "2"}, &.{
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

test "TestOutlineSpansTrailingBlockCommentsAfterStatements" {
    const content =
        \\console.log(0);
        \\[|/*
        \\/ * Some text
        \\  */|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOutliningSpans(undefined);
}

test "TestCompletionsWithOptionalPropertiesGeneric" {
    const content =
        \\// @strict: true
        \\interface MyOptions {
        \\    hello?: boolean;
        \\    world?: boolean;
        \\}
        \\declare function bar<T extends MyOptions>(options?: Partial<T>): void;
        \\bar({ hello, /*1*/ });
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
//                     .Label =      "world?",
//                     .InsertText = undefined("world"),
//                     .FilterText = undefined("world"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//             },
//         },
//     });
}

test "TestImportNameCodeFixExistingImport5" {
    const content =
        \\[|import "./module";
        \\f1/*0*/();|]
        \\// @Filename: module.ts
        \\export function f1() {}
        \\export var v1 = 5;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import \"./module\";\nimport { f1 } from \"./module\";\nf1();",
    }, null );
}

test "TestQuickInfoRecursiveObjectLiteral" {
    const content =
        \\var a = { f: /**/a
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "var a: any", "");
}

test "TestGoToDefinitionShadowVariableInsideModule" {
    const content =
        \\namespace shdModule {
        \\    var /*shadowVariableDefinition*/shdVar;
        \\    /*shadowVariableReference*/shdVar = 1;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, false, "shadowVariableReference");
}

test "TestQuickInfoNestedGenericCalls" {
    const content =
        \\// @strict: true
        \\/*1*/m({ foo: /*2*/$("foo") });
        \\m({ foo: /*3*/$("foo") });
        \\declare const m: <S extends string>(s: { [_ in S]: { $: NoInfer<S> } }) => void
        \\declare const $: <S, T extends S>(s: T) => { $: S }
        \\type NoInfer<T> = [T][T extends any ? 0 : never];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "const m: <\"foo\">(s: {\n    foo: {\n        $: \"foo\";\n    };\n}) => void", "");
    // f.VerifyQuickInfoAt(undefined, "2", "const $: <unknown, string>(s: string) => {\n    $: unknown;\n}", "");
    // f.VerifyQuickInfoAt(undefined, "3", "const $: <unknown, string>(s: string) => {\n    $: unknown;\n}", "");
}

test "TestSignatureHelpTaggedTemplatesNegatives5" {
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

test "TestCompletionForStringLiteral_quotePreference6" {
    const content =
        \\type T = "0" | "1";
        \\const t: T = /**/
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
//                     .Label = "\"1\"",
//                 },
//                 &.{
//                     .Label = "\"0\"",
//                 },
//             },
//         },
//         .UserPreferences = &.{.QuotePreference = lsutil.QuotePreference("double")},
//     });
}

test "TestCompletionsJsxExpression" {
    const content =
        \\// @Filename: /a.tsx
        \\// @jsx: react
        \\declare namespace JSX {
        \\    interface IntrinsicElements {
        \\        div: { a: string, b: string }
        \\    }
        \\}
        \\const value = "test";
        \\<div a={v/**/} />
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
//                     .Label =    "value",
//                     .Kind =     undefined(lsproto.CompletionItemKindVariable),
//                     .SortText = undefined(string(ls.SortTextLocationPriority)),
//                 },
//             },
//         },
//     });
}

test "TestQuickInfoOnFunctionPropertyReturnedFromGenericFunction1" {
    const content =
        \\function createProps<T>(t: T) {
        \\  function getProps() {}
        \\  function createVariants() {}
        \\
        \\  getProps.createVariants = createVariants;
        \\  return getProps;
        \\}
        \\
        \\createProps({})./**/createVariants();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "(property) getProps<{}>.createVariants: () => void", "");
}

test "TestCompletionsWithDeprecatedTag3" {
    const content =
        \\/** @deprecated foo */
        \\declare function foo<T>();
        \\/** ok */
        \\declare function foo<T>(x);
        \\
        \\foo/**/
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
//                     .Label =    "foo",
//                     .Kind =     undefined(lsproto.CompletionItemKindFunction),
//                     .SortText = undefined(string(ls.SortTextLocationPriority)),
//                 },
//             },
//         },
//     });
}

test "TestCodeFixMissingTypeAnnotationOnExports8" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\function foo() {return 42;}
        \\export const g = function () { return foo(); };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFixAvailable(undefined, &.{"Add return type 'number'"});
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Add return type 'number'",
        .NewFileContent = "function foo() {return 42;}\nexport const g = function (): number { return foo(); };",
        .Index = 0,
    });
}

test "TestGetOccurrencesAbstract03" {
    const content =
        \\function f() {
        \\    [|abstract|] class A {
        \\        [|abstract|] m(): void;
        \\    }
        \\    abstract class B {}
        \\}
        \\switch (0) {
        \\    case 0:
        \\        [|abstract|] class A { [|abstract|] m(): void; }
        \\    default:
        \\        [|abstract|] class B { [|abstract|] m(): void; }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestGenericTypeParamUnrelatedToArguments1" {
    const content =
        \\interface Foo<T> {
        \\    new (x: number): Foo<T>;
        \\}
        \\declare var f/*1*/1: Foo<number>;
        \\var f/*2*/2: Foo<number>;
        \\var f/*3*/3 = new Foo(3);
        \\var f/*4*/4: Foo<number> = new Foo(3);
        \\var f/*5*/5 = new Foo<number>(3);
        \\var f/*6*/6: Foo<number> = new Foo<number>(3);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "var f1: Foo<number>", "");
    // f.VerifyQuickInfoAt(undefined, "2", "var f2: Foo<number>", "");
    // f.VerifyQuickInfoAt(undefined, "3", "var f3: any", "");
    // f.VerifyQuickInfoAt(undefined, "4", "var f4: Foo<number>", "");
    // f.VerifyQuickInfoAt(undefined, "5", "var f5: any", "");
    // f.VerifyQuickInfoAt(undefined, "6", "var f6: Foo<number>", "");
}

test "TestFormattingGlobalAugmentation2" {
    const content =
        \\declare module "A" {
        \\/*1*/                  global                {
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyCurrentLineContent(undefined, "    global {");
}

test "TestCompletionOfAwaitPromise1" {
    const content =
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
//             .Includes = &.{
//                 "then",
//                 &.{
//                     .Label =      "trim",
//                     .InsertText = undefined("(await x).trim"),
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

test "TestCompletionsWithOptionalProperties" {
    const content =
        \\// @strict: true
        \\interface Options {
        \\    hello?: boolean;
        \\    world?: boolean;
        \\}
        \\declare function foo(options?: Options): void;
        \\foo({
        \\    hello: true,
        \\    /**/
        \\});
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
//                     .Label =      "world?",
//                     .InsertText = undefined("world"),
//                     .FilterText = undefined("world"),
//                     .Kind =       undefined(lsproto.CompletionItemKindField),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//             },
//         },
//     });
}

test "TestCodeFixClassImplementInterfaceIndexType" {
    const content =
        \\interface I<X> {
        \\    x: keyof X;
        \\}
        \\class C<Y> implements I<Y> {[| |]}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'I<Y>'",
        .NewFileContent = "interface I<X> {\n    x: keyof X;\n}\nclass C<Y> implements I<Y> {\n    x: keyof Y;\n}",
        .Index = 0,
    });
}

test "TestFormattingFatArrowFunctions" {
    const content =
        \\// valid
        \\    (         )           =>    1  ;/*1*/
        \\    (        arg )           =>    2  ;/*2*/
        \\        arg       =>    2  ;/*3*/
        \\        arg=>2  ;/*3a*/
        \\      (        arg     = 1 )           =>    3  ;/*4*/
        \\    (        arg    ?        )           =>    4  ;/*5*/
        \\    (        arg    :    number )           =>    5  ;/*6*/
        \\      (        arg    :    number     = 0 )           =>    6  ;/*7*/
        \\    (        arg        ?                  :    number )           =>    7  ;/*8*/
        \\    (                 ...     arg    :    number   [      ]    )           =>    8  ;/*9*/
        \\      (        arg1   ,    arg2 )           =>    12  ;/*10*/
        \\    (        arg1     = 1   ,    arg2     =3 )           =>    13  ;/*11*/
        \\      (        arg1    ?          ,    arg2    ?        )           =>    14  ;/*12*/
        \\    (        arg1    :    number   ,    arg2    :    number )           =>    15  ;/*13*/
        \\    (        arg1    :    number     = 0   ,    arg2    :    number     = 1 )           =>    16  ;/*14*/
        \\      (        arg1    ?           :    number   ,    arg2    ?           :    number )           =>    17  ;/*15*/
        \\    (        arg1   ,             ...     arg2    :    number   [      ]    )           =>    18  ;/*16*/
        \\      (        arg1   ,    arg2    ?           :    number )           =>    19  ;/*17*/
        \\
        \\// in paren
        \\    (            (         )           =>    21 )      ;/*18*/
        \\    (            (        arg )           =>    22 )      ;/*19*/
        \\    (            (        arg     = 1 )           =>    23 )      ;/*20*/
        \\    (            (        arg    ?        )           =>    24 )      ;/*21*/
        \\    (            (        arg    :    number )           =>    25 )      ;/*22*/
        \\    (            (        arg    :    number     = 0 )           =>    26 )      ;/*23*/
        \\    (            (        arg    ?           :    number )           =>    27 )      ;/*24*/
        \\    (            (                 ...     arg    :    number   [      ]    )           =>    28 )      ;/*25*/
        \\
        \\// in multiple paren
        \\    (            (            (            (            (        arg )           =>    { return 32  ;    } )     )     )     )      ;/*26*/
        \\
        \\// in ternary exression
        \\      false        ?            (         )           =>    41     :    null  ;/*27*/
        \\   false        ?            (        arg )           =>    42     :    null  ;/*28*/
        \\    false        ?            (        arg     = 1 )           =>    43     :    null  ;/*29*/
        \\      false        ?            (        arg    ?        )           =>    44     :    null  ;/*30*/
        \\    false        ?            (        arg    :    number )           =>    45     :    null  ;/*31*/
        \\   false        ?            (        arg    ?           :    number )           =>    46     :    null  ;/*32*/
        \\      false        ?            (        arg    ?           :    number     = 0 )           =>    47     :    null  ;/*33*/
        \\   false        ?            (                 ...     arg    :    number   [      ]    )           =>    48     :    null  ;/*34*/
        \\
        \\// in ternary exression within paren
        \\   false        ?            (            (         )           =>    51 )         :    null  ;/*35*/
        \\    false        ?            (            (        arg )           =>    52 )         :    null  ;/*36*/
        \\    false        ?            (            (        arg     = 1 )           =>    53 )         :    null  ;/*37*/
        \\      false        ?            (            (        arg    ?        )           =>    54 )         :    null  ;/*38*/
        \\    false        ?            (            (        arg    :    number )           =>    55 )         :    null  ;/*39*/
        \\      false        ?            (            (        arg    ?           :    number )           =>    56 )         :    null  ;/*40*/
        \\    false        ?            (            (        arg    ?           :    number     = 0 )           =>    57 )         :    null  ;/*41*/
        \\   false        ?            (            (                 ...     arg    :    number   [      ]    )           =>    58 )         :    null  ;/*42*/
        \\
        \\// ternary exression's else clause
        \\   false        ?        null     :        (         )           =>    61  ;/*43*/
        \\        false        ?        null     :        (        arg )           =>    62  ;/*44*/
        \\   false        ?        null     :        (        arg     = 1 )           =>    63  ;/*45*/
        \\      false        ?        null     :        (        arg    ?        )           =>    64  ;/*46*/
        \\   false        ?        null     :        (        arg    :    number )           =>    65  ;/*47*/
        \\    false        ?        null     :        (        arg    ?           :    number )           =>    66  ;/*48*/
        \\        false        ?        null     :        (        arg    ?           :    number     = 0 )           =>    67  ;/*49*/
        \\    false        ?        null     :        (                 ...     arg    :    number   [      ]    )           =>    68  ;/*50*/
        \\
        \\
        \\// nested ternary expressions
        \\    ((        a    ?        )           =>    { return a  ;    })     ?            (        b    ?         )           =>    { return b  ;    }     :        (        c    ?         )           =>    { return c  ;    }  ;/*51*/
        \\
        \\//multiple levels
        \\    ((        a    ?        )           =>    { return a  ;    })     ?            (        b )          =>       (        c )          =>   81     :        (        c )          =>       (        d )          =>   82  ;/*52*/
        \\
        \\
        \\// In Expressions
        \\    (            (        arg )           =>    90 )     instanceof Function  ;/*53*/
        \\      (            (        arg     = 1 )           =>    91 )     instanceof Function  ;/*54*/
        \\        (            (        arg    ?         )           =>    92 )     instanceof Function  ;/*55*/
        \\      (            (        arg    :    number )           =>    93 )     instanceof Function  ;/*56*/
        \\    (            (        arg    :    number     = 1 )           =>    94 )     instanceof Function  ;/*57*/
        \\        (            (        arg    ?           :    number )           =>    95 )     instanceof Function  ;/*58*/
        \\      (            (                 ...     arg    :    number   [      ]    )           =>    96 )     instanceof Function  ;/*59*/
        \\
        \\''    +        ((        arg )           =>    100)  ;/*60*/
        \\        (            (        arg )           =>    0 )        +    ''    +        ((        arg )           =>    101)  ;/*61*/
        \\          (            (        arg     = 1 )           =>    0 )        +    ''    +        ((        arg     = 2 )           =>    102)  ;/*62*/
        \\    (            (        arg    ?        )           =>    0 )        +    ''    +        ((        arg    ?        )           =>    103)  ;/*63*/
        \\      (            (        arg    :   number )           =>    0 )        +    ''    +        ((        arg    :   number )           =>    104)  ;/*64*/
        \\        (            (        arg    :   number     = 1 )           =>    0 )        +    ''    +        ((        arg    :   number     = 2 )           =>    105)  ;/*65*/
        \\    (            (        arg    ?           :   number     )           =>    0 )        +    ''    +        ((        arg    ?           :   number     )           =>    106)  ;/*66*/
        \\      (            (                 ...     arg    :   number   [      ]    )           =>    0 )        +    ''    +        ((                 ...     arg    :   number   [      ]    )           =>    107)  ;/*67*/
        \\    (            (        arg1   ,    arg2    ?        )           =>    0 )        +    ''    +        ((        arg1   ,   arg2    ?        )           =>    108)  ;/*68*/
        \\      (            (        arg1   ,             ...     arg2    :   number   [      ]    )           =>    0 )        +    ''    +        ((        arg1   ,             ...     arg2    :   number   [      ]    )           =>    108)  ;/*69*/
        \\
        \\
        \\// Function Parameters
        \\/*70*/function foo    (                 ...     arg    :    any   [      ]    )     { }
        \\
        \\/*71*/foo    (
        \\/*72*/        (        a )           =>    110   ,
        \\/*73*/        (            (        a )           =>    111 )       ,
        \\/*74*/        (        a )           =>    {
        \\        return /*75*/112  ;
        \\/*76*/    }   ,
        \\/*77*/        (        a    ?         )           =>    113   ,
        \\/*78*/        (        a   ,    b    ?         )           =>    114   ,
        \\/*79*/        (        a    :    number )           =>    115   ,
        \\/*80*/        (        a    :    number     = 0 )           =>    116   ,
        \\/*81*/        (        a     = 0 )           =>    117   ,
        \\/*82*/        (        a               :    number     = 0 )           =>    118   ,
        \\/*83*/        (        a    ?    ,   b   ?          :    number      )           =>    118   ,
        \\/*84*/        (                 ...     a    :    number   [      ]    )           =>    119   ,
        \\/*85*/        (        a   ,    b                = 0   ,             ...     c    :    number   [      ]    )           =>    120   ,
        \\/*86*/        (        a )           =>        (        b )           =>        (        c )           =>    121   ,
        \\/*87*/        false       ?            (        a )           =>    0     :        (        b )           =>    122
        \\ /*88*/)      ;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyCurrentLineContent(undefined, "() => 1;");
    _ = f.GoToMarker(undefined, "2");
    _ = f.VerifyCurrentLineContent(undefined, "(arg) => 2;");
    _ = f.GoToMarker(undefined, "3");
    _ = f.VerifyCurrentLineContent(undefined, "arg => 2;");
    _ = f.GoToMarker(undefined, "3a");
    _ = f.VerifyCurrentLineContent(undefined, "arg => 2;");
    _ = f.GoToMarker(undefined, "4");
    _ = f.VerifyCurrentLineContent(undefined, "(arg = 1) => 3;");
    _ = f.GoToMarker(undefined, "5");
    _ = f.VerifyCurrentLineContent(undefined, "(arg?) => 4;");
    _ = f.GoToMarker(undefined, "6");
    _ = f.VerifyCurrentLineContent(undefined, "(arg: number) => 5;");
    _ = f.GoToMarker(undefined, "7");
    _ = f.VerifyCurrentLineContent(undefined, "(arg: number = 0) => 6;");
    _ = f.GoToMarker(undefined, "8");
    _ = f.VerifyCurrentLineContent(undefined, "(arg?: number) => 7;");
    _ = f.GoToMarker(undefined, "9");
    _ = f.VerifyCurrentLineContent(undefined, "(...arg: number[]) => 8;");
    _ = f.GoToMarker(undefined, "10");
    _ = f.VerifyCurrentLineContent(undefined, "(arg1, arg2) => 12;");
    _ = f.GoToMarker(undefined, "11");
    _ = f.VerifyCurrentLineContent(undefined, "(arg1 = 1, arg2 = 3) => 13;");
    _ = f.GoToMarker(undefined, "12");
    _ = f.VerifyCurrentLineContent(undefined, "(arg1?, arg2?) => 14;");
    _ = f.GoToMarker(undefined, "13");
    _ = f.VerifyCurrentLineContent(undefined, "(arg1: number, arg2: number) => 15;");
    _ = f.GoToMarker(undefined, "14");
    _ = f.VerifyCurrentLineContent(undefined, "(arg1: number = 0, arg2: number = 1) => 16;");
    _ = f.GoToMarker(undefined, "15");
    _ = f.VerifyCurrentLineContent(undefined, "(arg1?: number, arg2?: number) => 17;");
    _ = f.GoToMarker(undefined, "16");
    _ = f.VerifyCurrentLineContent(undefined, "(arg1, ...arg2: number[]) => 18;");
    _ = f.GoToMarker(undefined, "17");
    _ = f.VerifyCurrentLineContent(undefined, "(arg1, arg2?: number) => 19;");
    _ = f.GoToMarker(undefined, "18");
    _ = f.VerifyCurrentLineContent(undefined, "(() => 21);");
    _ = f.GoToMarker(undefined, "19");
    _ = f.VerifyCurrentLineContent(undefined, "((arg) => 22);");
    _ = f.GoToMarker(undefined, "20");
    _ = f.VerifyCurrentLineContent(undefined, "((arg = 1) => 23);");
    _ = f.GoToMarker(undefined, "21");
    _ = f.VerifyCurrentLineContent(undefined, "((arg?) => 24);");
    _ = f.GoToMarker(undefined, "22");
    _ = f.VerifyCurrentLineContent(undefined, "((arg: number) => 25);");
    _ = f.GoToMarker(undefined, "23");
    _ = f.VerifyCurrentLineContent(undefined, "((arg: number = 0) => 26);");
    _ = f.GoToMarker(undefined, "24");
    _ = f.VerifyCurrentLineContent(undefined, "((arg?: number) => 27);");
    _ = f.GoToMarker(undefined, "25");
    _ = f.VerifyCurrentLineContent(undefined, "((...arg: number[]) => 28);");
    _ = f.GoToMarker(undefined, "26");
    _ = f.VerifyCurrentLineContent(undefined, "(((((arg) => { return 32; }))));");
    _ = f.GoToMarker(undefined, "27");
    _ = f.VerifyCurrentLineContent(undefined, "false ? () => 41 : null;");
    _ = f.GoToMarker(undefined, "28");
    _ = f.VerifyCurrentLineContent(undefined, "false ? (arg) => 42 : null;");
    _ = f.GoToMarker(undefined, "29");
    _ = f.VerifyCurrentLineContent(undefined, "false ? (arg = 1) => 43 : null;");
    _ = f.GoToMarker(undefined, "30");
    _ = f.VerifyCurrentLineContent(undefined, "false ? (arg?) => 44 : null;");
    _ = f.GoToMarker(undefined, "31");
    _ = f.VerifyCurrentLineContent(undefined, "false ? (arg: number) => 45 : null;");
    _ = f.GoToMarker(undefined, "32");
    _ = f.VerifyCurrentLineContent(undefined, "false ? (arg?: number) => 46 : null;");
    _ = f.GoToMarker(undefined, "33");
    _ = f.VerifyCurrentLineContent(undefined, "false ? (arg?: number = 0) => 47 : null;");
    _ = f.GoToMarker(undefined, "34");
    _ = f.VerifyCurrentLineContent(undefined, "false ? (...arg: number[]) => 48 : null;");
    _ = f.GoToMarker(undefined, "35");
    _ = f.VerifyCurrentLineContent(undefined, "false ? (() => 51) : null;");
    _ = f.GoToMarker(undefined, "36");
    _ = f.VerifyCurrentLineContent(undefined, "false ? ((arg) => 52) : null;");
    _ = f.GoToMarker(undefined, "37");
    _ = f.VerifyCurrentLineContent(undefined, "false ? ((arg = 1) => 53) : null;");
    _ = f.GoToMarker(undefined, "38");
    _ = f.VerifyCurrentLineContent(undefined, "false ? ((arg?) => 54) : null;");
    _ = f.GoToMarker(undefined, "39");
    _ = f.VerifyCurrentLineContent(undefined, "false ? ((arg: number) => 55) : null;");
    _ = f.GoToMarker(undefined, "40");
    _ = f.VerifyCurrentLineContent(undefined, "false ? ((arg?: number) => 56) : null;");
    _ = f.GoToMarker(undefined, "41");
    _ = f.VerifyCurrentLineContent(undefined, "false ? ((arg?: number = 0) => 57) : null;");
    _ = f.GoToMarker(undefined, "42");
    _ = f.VerifyCurrentLineContent(undefined, "false ? ((...arg: number[]) => 58) : null;");
    _ = f.GoToMarker(undefined, "43");
    _ = f.VerifyCurrentLineContent(undefined, "false ? null : () => 61;");
    _ = f.GoToMarker(undefined, "44");
    _ = f.VerifyCurrentLineContent(undefined, "false ? null : (arg) => 62;");
    _ = f.GoToMarker(undefined, "45");
    _ = f.VerifyCurrentLineContent(undefined, "false ? null : (arg = 1) => 63;");
    _ = f.GoToMarker(undefined, "46");
    _ = f.VerifyCurrentLineContent(undefined, "false ? null : (arg?) => 64;");
    _ = f.GoToMarker(undefined, "47");
    _ = f.VerifyCurrentLineContent(undefined, "false ? null : (arg: number) => 65;");
    _ = f.GoToMarker(undefined, "48");
    _ = f.VerifyCurrentLineContent(undefined, "false ? null : (arg?: number) => 66;");
    _ = f.GoToMarker(undefined, "49");
    _ = f.VerifyCurrentLineContent(undefined, "false ? null : (arg?: number = 0) => 67;");
    _ = f.GoToMarker(undefined, "50");
    _ = f.VerifyCurrentLineContent(undefined, "false ? null : (...arg: number[]) => 68;");
    _ = f.GoToMarker(undefined, "51");
    _ = f.VerifyCurrentLineContent(undefined, "((a?) => { return a; }) ? (b?) => { return b; } : (c?) => { return c; };");
    _ = f.GoToMarker(undefined, "52");
    _ = f.VerifyCurrentLineContent(undefined, "((a?) => { return a; }) ? (b) => (c) => 81 : (c) => (d) => 82;");
    _ = f.GoToMarker(undefined, "53");
    _ = f.VerifyCurrentLineContent(undefined, "((arg) => 90) instanceof Function;");
    _ = f.GoToMarker(undefined, "54");
    _ = f.VerifyCurrentLineContent(undefined, "((arg = 1) => 91) instanceof Function;");
    _ = f.GoToMarker(undefined, "55");
    _ = f.VerifyCurrentLineContent(undefined, "((arg?) => 92) instanceof Function;");
    _ = f.GoToMarker(undefined, "56");
    _ = f.VerifyCurrentLineContent(undefined, "((arg: number) => 93) instanceof Function;");
    _ = f.GoToMarker(undefined, "57");
    _ = f.VerifyCurrentLineContent(undefined, "((arg: number = 1) => 94) instanceof Function;");
    _ = f.GoToMarker(undefined, "58");
    _ = f.VerifyCurrentLineContent(undefined, "((arg?: number) => 95) instanceof Function;");
    _ = f.GoToMarker(undefined, "59");
    _ = f.VerifyCurrentLineContent(undefined, "((...arg: number[]) => 96) instanceof Function;");
    _ = f.GoToMarker(undefined, "60");
    _ = f.VerifyCurrentLineContent(undefined, "'' + ((arg) => 100);");
    _ = f.GoToMarker(undefined, "61");
    _ = f.VerifyCurrentLineContent(undefined, "((arg) => 0) + '' + ((arg) => 101);");
    _ = f.GoToMarker(undefined, "62");
    _ = f.VerifyCurrentLineContent(undefined, "((arg = 1) => 0) + '' + ((arg = 2) => 102);");
    _ = f.GoToMarker(undefined, "63");
    _ = f.VerifyCurrentLineContent(undefined, "((arg?) => 0) + '' + ((arg?) => 103);");
    _ = f.GoToMarker(undefined, "64");
    _ = f.VerifyCurrentLineContent(undefined, "((arg: number) => 0) + '' + ((arg: number) => 104);");
    _ = f.GoToMarker(undefined, "65");
    _ = f.VerifyCurrentLineContent(undefined, "((arg: number = 1) => 0) + '' + ((arg: number = 2) => 105);");
    _ = f.GoToMarker(undefined, "66");
    _ = f.VerifyCurrentLineContent(undefined, "((arg?: number) => 0) + '' + ((arg?: number) => 106);");
    _ = f.GoToMarker(undefined, "67");
    _ = f.VerifyCurrentLineContent(undefined, "((...arg: number[]) => 0) + '' + ((...arg: number[]) => 107);");
    _ = f.GoToMarker(undefined, "68");
    _ = f.VerifyCurrentLineContent(undefined, "((arg1, arg2?) => 0) + '' + ((arg1, arg2?) => 108);");
    _ = f.GoToMarker(undefined, "69");
    _ = f.VerifyCurrentLineContent(undefined, "((arg1, ...arg2: number[]) => 0) + '' + ((arg1, ...arg2: number[]) => 108);");
    _ = f.GoToMarker(undefined, "70");
    _ = f.VerifyCurrentLineContent(undefined, "function foo(...arg: any[]) { }");
    _ = f.GoToMarker(undefined, "71");
    _ = f.VerifyCurrentLineContent(undefined, "foo(");
    _ = f.GoToMarker(undefined, "72");
    _ = f.VerifyCurrentLineContent(undefined, "    (a) => 110,");
    _ = f.GoToMarker(undefined, "73");
    _ = f.VerifyCurrentLineContent(undefined, "    ((a) => 111),");
    _ = f.GoToMarker(undefined, "74");
    _ = f.VerifyCurrentLineContent(undefined, "    (a) => {");
    _ = f.GoToMarker(undefined, "75");
    _ = f.VerifyCurrentLineContent(undefined, "        return 112;");
    _ = f.GoToMarker(undefined, "76");
    _ = f.VerifyCurrentLineContent(undefined, "    },");
    _ = f.GoToMarker(undefined, "77");
    _ = f.VerifyCurrentLineContent(undefined, "    (a?) => 113,");
    _ = f.GoToMarker(undefined, "78");
    _ = f.VerifyCurrentLineContent(undefined, "    (a, b?) => 114,");
    _ = f.GoToMarker(undefined, "79");
    _ = f.VerifyCurrentLineContent(undefined, "    (a: number) => 115,");
    _ = f.GoToMarker(undefined, "80");
    _ = f.VerifyCurrentLineContent(undefined, "    (a: number = 0) => 116,");
    _ = f.GoToMarker(undefined, "81");
    _ = f.VerifyCurrentLineContent(undefined, "    (a = 0) => 117,");
    _ = f.GoToMarker(undefined, "82");
    _ = f.VerifyCurrentLineContent(undefined, "    (a: number = 0) => 118,");
    _ = f.GoToMarker(undefined, "83");
    _ = f.VerifyCurrentLineContent(undefined, "    (a?, b?: number) => 118,");
    _ = f.GoToMarker(undefined, "84");
    _ = f.VerifyCurrentLineContent(undefined, "    (...a: number[]) => 119,");
    _ = f.GoToMarker(undefined, "85");
    _ = f.VerifyCurrentLineContent(undefined, "    (a, b = 0, ...c: number[]) => 120,");
    _ = f.GoToMarker(undefined, "86");
    _ = f.VerifyCurrentLineContent(undefined, "    (a) => (b) => (c) => 121,");
    _ = f.GoToMarker(undefined, "87");
    _ = f.VerifyCurrentLineContent(undefined, "    false ? (a) => 0 : (b) => 122");
}

test "TestJsdocLink_rename1" {
    const content =
        \\interface A/**/ {}
        \\/**
        \\ * {@link A()} is ok
        \\ */
        \\declare const a: A
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRename(undefined, null , "");
}

test "TestRemoveDeclareInModule" {
    const content =
        \\/**/export namespace Foo {
        \\    function a(): void {}
        \\}
        \\
        \\Foo.a();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.DeleteAtCaret(undefined, 7);
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
}

test "TestOrganizeImportsGroup_MultilineCommentInNewline" {
    const content =
        \\// polyfill
        \\import c from "C";
        \\/*
        \\* demo
        \\*/
        \\import d from "D";
        \\import a from "A";
        \\import b from "B";
        \\
        \\console.log(a, b, c, d)
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOrganizeImports(undefined,
//         "// polyfill\nimport c from \"C\";\n/*\n* demo\n*/\nimport a from \"A\";\nimport b from \"B\";\nimport d from \"D\";\n\nconsole.log(a, b, c, d)",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
}

test "TestCompletionListAtDeclarationOfParameterType" {
    const content =
        \\namespace Bar {
        \\    export class Bleah {
        \\    }
        \\    export class Foo extends Bleah {
        \\    }
        \\}
        \\
        \\function Blah(x: /**/Bar.Bleah) {
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
//                 "Bar",
//             },
//         },
//     });
}

test "TestTypeOperatorNodeBuilding" {
    const content =
        \\// @Filename: keyof.ts
        \\function doSomethingWithKeys<T>(...keys: (keyof T)[]) { }
        \\
        \\const /*1*/utilityFunctions = {
        \\  doSomethingWithKeys
        \\};
        \\// @Filename: typeof.ts
        \\class Foo { static a: number; }
        \\function doSomethingWithTypes(...statics: (typeof Foo)[]) {}
        \\
        \\const /*2*/utilityFunctions = {
        \\  doSomethingWithTypes
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "const utilityFunctions: {\n    doSomethingWithKeys: <T>(...keys: (keyof T)[]) => void;\n}", "");
    // f.VerifyQuickInfoAt(undefined, "2", "const utilityFunctions: {\n    doSomethingWithTypes: (...statics: (typeof Foo)[]) => void;\n}", "");
}

test "TestRenameParameterPropertyDeclaration4" {
    const content =
        \\class Foo {
        \\    constructor([|protected { [|{| "contextRangeIndex": 0 |}protectedParam|] }|]) {
        \\        let myProtectedParam = [|protectedParam|];
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRename(undefined, null , f.Ranges()[1], f.Ranges()[2]);
}

test "TestCompletionsImportTypeKeyword" {
    const content =
        \\// @module: node18
        \\// @Filename: /os.d.ts
        \\declare module "os" {
        \\  export function type(): string;
        \\}
        \\// @Filename: /index.ts
        \\type/**/
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
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//                 &.{
//                     .Label = "type",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "os",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
}

test "TestExportDefaultClass" {
    const content =
        \\export default class C {
        \\    method() { /*1*/ }
        \\}
        \\ /*2*/
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
//                     .Label =  "C",
//                     .Detail = undefined("class C"),
//                     .Kind =   undefined(lsproto.CompletionItemKindClass),
//                 },
//             },
//         },
//     });
}

test "TestTsxRename2" {
    const content =
        \\//@Filename: file.tsx
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\        div: {
        \\            [|[|{| "contextRangeIndex": 0 |}name|]?: string;|]
        \\            isOpen?: boolean;
        \\        };
        \\        span: { n: string; };
        \\    }
        \\}
        \\var x = <div [|[|{| "contextRangeIndex": 2 |}name|]="hello"|] />;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRenameAtRangesWithText(undefined, null , "name");
}

test "TestProtoPropertyInObjectLiteral" {
    const content =
        \\var o1 = {
        \\    "__proto__": 10
        \\};
        \\var o2 = {
        \\    __proto__: 10
        \\};
        \\o1./*1*/
        \\o2./*2*/
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
//                     .Label =  "__proto__",
//                     .Detail = undefined("(property) \"__proto__\": number"),
//                 },
//             },
//         },
//     });
    _ = f.Insert(undefined, "__proto__ = 10;");
    // f.VerifyQuickInfoAt(undefined, "1", "(property) \"__proto__\": number", "");
    // f.VerifyCompletions(undefined, "2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =  "__proto__",
//                     .Detail = undefined("(property) __proto__: number"),
//                 },
//             },
//         },
//     });
    _ = f.Insert(undefined, "__proto__ = 10;");
    // f.VerifyQuickInfoAt(undefined, "2", "(property) __proto__: number", "");
}

test "TestSignatureHelpObjectCreationExpressionNoArgs_NotAvailable" {
    const content =
        \\class sampleCls { constructor(str: string, num: number) { } }
        \\var x = new sampleCls/**/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyNoSignatureHelpForMarkers(undefined, "");
}

test "TestCodeFixTopLevelForAwait_module_blankCompilerOptionsInTsConfig" {
    const content =
        \\// @filename: /dir/a.ts
        \\declare const p: number[];
        \\for await (const _ of p);
        \\export {};
        \\// @filename: /dir/tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "module": "commonjs"
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCodeFixNotAvailable(undefined, "fixModuleOption");
}

test "TestNoCompletionListOnCommentsInsideObjectLiterals" {
    const content =
        \\namespace ObjectLiterals {
        \\    interface MyPoint {
        \\        x1: number;
        \\        y1: number;
        \\    }
        \\
        \\    var p1: MyPoint = {
        \\        /* /*1*/ Comment /*2*/ */
        \\    };
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, f.Markers(), null);
}

test "TestCodeFixClassImplementInterfaceMemberNestedTypeAlias" {
    const content =
        \\type Either<T> = { val: T } | Error;
        \\interface I {
        \\    x: Either<Either<string>>;
        \\    foo(x: Either<Either<string>>): void;
        \\}
        \\class C implements I {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'I'",
        .NewFileContent = "type Either<T> = { val: T } | Error;\ninterface I {\n    x: Either<Either<string>>;\n    foo(x: Either<Either<string>>): void;\n}\nclass C implements I {\n    x: Either<Either<string>>;\n    foo(x: Either<Either<string>>): void {\n        throw new Error(\"Method not implemented.\");\n    }\n}",
        .Index = 0,
    });
}

test "TestCompletionInJSDocFunctionNew" {
    const content =
        \\// @allowJs: true
        \\// @Filename: Foo.js
        \\/** @type {function (new: string, string): string} */
        \\var f = function () { return new/**/; }
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
//                     .Label =    "new",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestJsDocTypeTagQuickInfo1" {
    const content =
        \\// @lib: es5
        \\// @strict: true
        \\// @allowJs: true
        \\// @Filename: jsDocTypeTag1.js
        \\/** @type {String} */
        \\var /*1*/S;
        \\/** @type {Number} */
        \\var /*2*/N;
        \\/** @type {Boolean} */
        \\var /*3*/B;
        \\/** @type {Void} */
        \\var /*4*/V;
        \\/** @type {Undefined} */
        \\var /*5*/U;
        \\/** @type {Null} */
        \\var /*6*/Nl;
        \\/** @type {Array} */
        \\var /*7*/A;
        \\/** @type {Promise} */
        \\var /*8*/P;
        \\/** @type {Object} */
        \\var /*9*/Obj;
        \\/** @type {Function} */
        \\var /*10*/Func;
        \\/** @type {*} */
        \\var /*11*/AnyType;
        \\/** @type {?} */
        \\var /*12*/QType;
        \\/** @type {String|Number} */
        \\var /*13*/SOrN;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestGetJavaScriptCompletions3" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: Foo.js
        \\/** @type {Array.<number>} */
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
//                     .Label = "concat",
//                     .Kind =  undefined(lsproto.CompletionItemKindMethod),
//                 },
//             },
//         },
//     });
}

test "TestDuplicateTypeParameters" {
    const content =
        \\class A<B, /**/B>  { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyQuickInfoExists(undefined);
}

test "TestCompletionsWithDeprecatedTag2" {
    const content =
        \\/** @deprecated foo */
        \\declare function foo<T>();
        \\/** @deprecated foo<T> */
        \\declare function foo<T>(x);
        \\
        \\foo/**/
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
//                     .Label =    "foo",
//                     .Kind =     undefined(lsproto.CompletionItemKindFunction),
//                     .SortText = undefined(string(ls.DeprecateSortText(ls.SortTextLocationPriority))),
//                     .Tags =     &&.{lsproto.CompletionItemTagDeprecated},
//                 },
//             },
//         },
//     });
}

test "TestCompletionsClassMemberImportTypeNodeParameter2" {
    const content =
        \\// @module: node18
        \\// @FileName: /index.d.ts
        \\export declare class Cls {
        \\  method(
        \\    param: import("./doesntexist.js").Foo,
        \\  ): import("./doesntexist.js").Foo;
        \\}
        \\
        \\export declare class Derived extends Cls {
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
//                     .Label =               "method",
//                     .InsertText =          undefined("method(param: import(\"./doesntexist.js\").Foo);"),
//                     .FilterText =          undefined("method"),
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                 },
//             },
//         },
//     });
}

test "TestDocCommentTemplateIndentation" {
    const content =
        \\// @Filename: indents.ts
        \\    a   /*2*/
        \\    /*1*/
        \\/*0*/        function foo() { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyJSDocCompletion(undefined, "0", 3, "/** */", null);
    // f.VerifyJSDocCompletion(undefined, "1", 3, "/** */", null);
    // f.VerifyJSDocCompletion(undefined, "2", 3, "/** */", null);
}

test "TestFormattingBlockInCaseClauses" {
    const content =
        \\switch (1) {
        \\    case 1:
        \\        {
        \\            /*1*/
        \\        break;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, "}");
    _ = f.VerifyCurrentLineContent(undefined, "        }");
}

test "TestSignatureHelpSuperConstructorOverload" {
    const content =
        \\class SuperOverloadBase {
        \\    constructor();
        \\    constructor(test: string);
        \\    constructor(test?: string) {
        \\    }
        \\}
        \\class SuperOverLoad1 extends SuperOverloadBase {
        \\    constructor() {
        \\        super(/*superOverload1*/);
        \\    }
        \\}
        \\class SuperOverLoad2 extends SuperOverloadBase {
        \\    constructor() {
        \\        super(""/*superOverload2*/);
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "superOverload1");
    // f.VerifySignatureHelp(undefined, .{.Text = "SuperOverloadBase(): SuperOverloadBase", .ParameterCount = 0, .OverloadsCount = 2});
    _ = f.GoToMarker(undefined, "superOverload2");
    // f.VerifySignatureHelp(undefined, .{.Text = "SuperOverloadBase(test: string): SuperOverloadBase", .ParameterCount = 1, .ParameterName = "test", .ParameterSpan = "test: string", .OverloadsCount = 2});
}

test "TestFindAllRefsOnDecorators" {
    const content =
        \\// @Filename: a.ts
        \\/*1*/function /*2*/decorator(target) {
        \\    return target;
        \\}
        \\/*3*/decorator();
        \\// @Filename: b.ts
        \\@/*4*/decorator @/*5*/decorator("again")
        \\class C {
        \\    @/*6*/decorator
        \\    method() {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5", "6");
}

test "TestQuickInfoExtendArray" {
    const content =
        \\interface Foo<T> extends Array<T> { }
        \\var x: Foo<string>;
        \\var /*1*/r = x[0];
        \\interface Foo2 extends Array<string> { }
        \\var x2: Foo2;
        \\var /*2*/r2 = x2[0];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "var r: string", "");
    // f.VerifyQuickInfoAt(undefined, "2", "var r2: string", "");
}

test "TestJsDocPropertyDescription4" {
    const content =
        \\interface MultipleExample {
        \\    /** Something generic */
        \\    [key: string | number | symbol]: string;
        \\}
        \\function multipleExample(e: MultipleExample) {
        \\    console.log(e./*multiple*/anything);
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "multiple", "(index) MultipleExample[string | number | symbol]: string", "Something generic");
}

test "TestAddFunctionInDuplicatedConstructorClassBody" {
    const content =
        \\class Foo {
        \\    constructor() { }
        \\    constructor() { }
        \\    /**/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, "fn() { }");
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 2);
}

test "TestGeneratorDeclarationFormatting" {
    const content =
        \\function    *g() { }/*1*/
        \\var v = function    *() { };/*2*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyCurrentLineContent(undefined, "function* g() { }");
    _ = f.GoToMarker(undefined, "2");
    _ = f.VerifyCurrentLineContent(undefined, "var v = function*() { };");
}

test "TestFindAllRefsJsDocImportTag2" {
    const content =
        \\// @checkJs: true
        \\// @Filename: /component.js
        \\export default class Component {
        \\  constructor() {
        \\    this.id_ = Math.random();
        \\  }
        \\  id() {
        \\    return this.id_;
        \\  }
        \\}
        \\// @Filename: /spatial-navigation.js
        \\/** @import Component from './component.js' */
        \\
        \\export class SpatialNavigation {
        \\  /**
        \\   * @param {Component} component
        \\   */
        \\  add(component) {}
        \\}
        \\// @Filename: /player.js
        \\import Component from './component.js';
        \\
        \\/**
        \\ * @extends Component/*1*/
        \\ */
        \\export class Player extends Component {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestFormatOnOpenCurlyBraceRemoveNewLine" {
    const content =
        \\if(true)
        \\/**/ }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.GetOptions();
    // f.Configure(undefined, opts124);
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, "{");
    _ = f.VerifyCurrentFileContent(undefined, "if (true) { }");
}

test "TestQuickInfoJsdocTypedefMissingType" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\/**
        \\ * @typedef /**/A
        \\ */
        \\var x;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "type A = any", "");
}

test "TestCompletionsImport_windowsPathsProjectRelative" {
    const content =
        \\// @Filename: c:/project/tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "paths": {
        \\      "~/noIndex/*": ["./src/noIndex/*"],
        \\      "~/withIndex": ["./src/withIndex/index.ts"]
        \\    }
        \\  }
        \\}
        \\// @Filename: c:/project/package.json
        \\{}
        \\// @Filename: c:/project/src/noIndex/a.ts
        \\export const myFunctionA = () => {};
        \\// @Filename: c:/project/src/withIndex/b.ts
        \\export const myFunctionB = () => {};
        \\// @Filename: c:/project/src/withIndex/index.ts
        \\export * from './b';
        \\// @Filename: c:/project/src/reproduction/1.ts
        \\myFunction/**/
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
//                     .Label = "myFunctionA",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "~/noIndex/a",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//                 &.{
//                     .Label = "myFunctionB",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "~/withIndex",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//         .UserPreferences = &.{.ImportModuleSpecifierPreference = "non-relative"},
//     });
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label = "myFunctionA",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "../noIndex/a",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//                 &.{
//                     .Label = "myFunctionB",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "../withIndex",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//         .UserPreferences = &.{.ImportModuleSpecifierPreference = "relative"},
//     });
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label = "myFunctionA",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "../noIndex/a",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//                 &.{
//                     .Label = "myFunctionB",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "../withIndex",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//         .UserPreferences = &.{.ImportModuleSpecifierPreference = "project-relative"},
//     });
}

test "TestQuickInfoCommentsCommentParsing" {
    const content =
        \\/// This is simple /// comments
        \\function simple() {
        \\}
        \\
        \\sim/*1q*/ple( );
        \\
        \\/// multiLine /// Comments
        \\/// This is example of multiline /// comments
        \\/// Another multiLine
        \\function multiLine() {
        \\}
        \\mul/*2q*/tiLine( );
        \\
        \\/** this is eg of single line jsdoc style comment */
        \\function jsDocSingleLine() {
        \\}
        \\jsDoc/*3q*/SingleLine();
        \\
        \\
        \\/** this is multiple line jsdoc stule comment
        \\*New line1
        \\*New Line2*/
        \\function jsDocMultiLine() {
        \\}
        \\jsDocM/*4q*/ultiLine();
        \\
        \\/** multiple line jsdoc comments no longer merge
        \\*New line1
        \\*New Line2*/
        \\/** Shoul mege this line as well
        \\* and this too*/ /** Another this one too*/
        \\function jsDocMultiLineMerge() {
        \\}
        \\jsDocMu/*5q*/ltiLineMerge();
        \\
        \\
        \\/// Triple slash comment
        \\/** jsdoc comment */
        \\function jsDocMixedComments1() {
        \\}
        \\jsDocMix/*6q*/edComments1();
        \\
        \\/// Triple slash comment
        \\/** jsdoc comment */ /** another jsDocComment*/
        \\function jsDocMixedComments2() {
        \\}
        \\jsDocMi/*7q*/xedComments2();
        \\
        \\/** jsdoc comment */ /*** triplestar jsDocComment*/
        \\/// Triple slash comment
        \\function jsDocMixedComments3() {
        \\}
        \\jsDocMixe/*8q*/dComments3();
        \\
        \\/** jsdoc comment */ /** another jsDocComment*/
        \\/// Triple slash comment
        \\/// Triple slash comment 2
        \\function jsDocMixedComments4() {
        \\}
        \\jsDocMixed/*9q*/Comments4();
        \\
        \\/// Triple slash comment 1
        \\/** jsdoc comment */ /** another jsDocComment*/
        \\/// Triple slash comment
        \\/// Triple slash comment 2
        \\function jsDocMixedComments5() {
        \\}
        \\jsDocM/*10q*/ixedComments5();
        \\
        \\/** another jsDocComment*/
        \\/// Triple slash comment 1
        \\/// Triple slash comment
        \\/// Triple slash comment 2
        \\/** jsdoc comment */
        \\function jsDocMixedComments6() {
        \\}
        \\jsDocMix/*11q*/edComments6();
        \\
        \\// This shoulnot be help comment
        \\function noHelpComment1() {
        \\}
        \\noHel/*12q*/pComment1();
        \\
        \\/* This shoulnot be help comment */
        \\function noHelpComment2() {
        \\}
        \\noHelpC/*13q*/omment2();
        \\
        \\function noHelpComment3() {
        \\}
        \\noHelpC/*14q*/omment3();
        \\/** Adds two integers and returns the result
        \\  * @param {number} a first number
        \\  * @param b second number
        \\  */
        \\function sum(/*16aq*/a: number, /*17aq*/b: number) {
        \\    return a + b;
        \\}
        \\s/*16q*/um(10, 20);
        \\/** This is multiplication function
        \\ * @param 
        \\ * @param a first number
        \\ * @param b
        \\ * @param c {
        \\ @param d @anotherTag
        \\ * @param e LastParam @anotherTag*/
        \\function multiply(/*19aq*/a: number, /*20aq*/b: number, /*21aq*/c?: number, /*22aq*/d?, /*23aq*/e?) {
        \\}
        \\mult/*19q*/iply(10, 20, 30, 40, 50);
        \\/** fn f1 with number
        \\* @param { string} b about b
        \\*/
        \\function f1(/*25aq*/a: number);
        \\function f1(/*26aq*/b: string);
        \\/**@param opt optional parameter*/
        \\function f1(aOrb, opt?) {
        \\    return aOrb;
        \\}
        \\f/*25q*/1(10);
        \\f/*26q*/1("hello");
        \\
        \\/** This is subtract function
        \\@param { a
        \\*@param { number | } b this is about b
        \\@param { { () => string; } } c this is optional param c
        \\@param { { () => string; } d this is optional param d
        \\@param { { () => string; } } e this is optional param e
        \\@param { { { () => string; } } f this is optional param f
        \\*/
        \\function subtract(/*28aq*/a: number, /*29aq*/b: number, /*30aq*/c?: () => string, /*31aq*/d?: () => string, /*32aq*/e?: () => string, /*33aq*/f?: () => string) {
        \\}
        \\subt/*28q*/ract(10,  20,  null,  null,  null, null);
        \\/** this is square function
        \\@paramTag { number } a this is input number of paramTag
        \\@param { number } a this is input number
        \\@returnType { number } it is return type
        \\*/
        \\function square(/*34aq*/a: number) {
        \\    return a * a;
        \\}
        \\squ/*34q*/are(10);
        \\/** this is divide function
        \\@param { number} a this is a
        \\@paramTag { number } g this is optional param g
        \\@param { number} b this is b
        \\*/
        \\function divide(/*35aq*/a: number, /*36aq*/b: number) {
        \\}
        \\div/*35q*/ide(10, 20);
        \\/**
        \\Function returns string concat of foo and bar
        \\@param            {string}        foo        is string
        \\@param            {string}        bar        is second string
        \\*/
        \\function fooBar(/*37aq*/foo: string, /*38aq*/bar: string) {
        \\    return foo + bar;
        \\}
        \\fo/*37q*/oBar("foo","bar");
        \\/** This is a comment */
        \\var x;
        \\/**
        \\  * This is a comment
        \\  */
        \\var y;
        \\/** this is jsdoc style function with param tag as well as inline parameter help
        \\*@param a it is first parameter
        \\*@param c it is third parameter
        \\*/
        \\function jsDocParamTest(/** this is inline comment for a *//*40aq*/a: number, /** this is inline comment for b*/ /*41aq*/b: number, /*42aq*/c: number, /*43aq*/d: number) {
        \\    return a + b + c + d;
        \\}
        \\jsD/*40q*/ocParamTest(30, 40, 50, 60);
        \\/** This is function comment
        \\  * And properly aligned comment
        \\  */
        \\function jsDocCommentAlignmentTest1() {
        \\}
        \\jsDocCom/*45q*/mentAlignmentTest1();
        \\/** This is function comment
        \\  *     And aligned with 4 space char margin
        \\  */
        \\function jsDocCommentAlignmentTest2() {
        \\}
        \\jsDocComme/*46q*/ntAlignmentTest2();
        \\/** This is function comment
        \\  *     And aligned with 4 space char margin
        \\  * @param {string} a this is info about a
        \\  *                   spanning on two lines and aligned perfectly
        \\  * @param b          this is info about b
        \\  *                   spanning on two lines and aligned perfectly
        \\  *                   spanning one more line alined perfectly
        \\  *                       spanning another line with more margin
        \\  * @param c          this is info about b
        \\  *  not aligned text about parameter will eat only one space
        \\  */
        \\function jsDocCommentAlignmentTest3(/*47aq*/a: string, /*48aq*/b, /*49aq*/c) {
        \\}
        \\jsDocComme/*47q*/ntAlignmentTest3("hello",1, 2);
        \\/**/
        \\class NoQuic/*50q*/kInfoClass {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestCompletionListInObjectBindingPattern09" {
    const content =
        \\interface I {
        \\    propertyOfI_1: number;
        \\    propertyOfI_2: string;
        \\}
        \\interface J {
        \\    property1: I;
        \\    property2: string;
        \\}
        \\
        \\var foo: J;
        \\var { property1: { propertyOfI_1, }, /**/ } = foo;
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

test "TestFormattingofSingleLineBlockConstructs" {
    const content =
        \\namespace InternalModule/*1*/{}
        \\interface MyInterface/*2*/{}
        \\enum E/*3*/{}
        \\class MyClass/*4*/{
        \\constructor()/*cons*/{}
        \\        public MyFunction()/*5*/{return 0;}
        \\public get Getter()/*6*/{}
        \\public set Setter(x)/*7*/{}}
        \\function foo()/*8*/{{}}
        \\(function()/*10*/{});
        \\(() =>/*11*/{});
        \\var x :/*12*/{};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyCurrentLineContent(undefined, "namespace InternalModule { }");
    _ = f.GoToMarker(undefined, "2");
    _ = f.VerifyCurrentLineContent(undefined, "interface MyInterface { }");
    _ = f.GoToMarker(undefined, "3");
    _ = f.VerifyCurrentLineContent(undefined, "enum E { }");
    _ = f.GoToMarker(undefined, "4");
    _ = f.VerifyCurrentLineContent(undefined, "class MyClass {");
    _ = f.GoToMarker(undefined, "cons");
    _ = f.VerifyCurrentLineContent(undefined, "    constructor() { }");
    _ = f.GoToMarker(undefined, "5");
    _ = f.VerifyCurrentLineContent(undefined, "    public MyFunction() { return 0; }");
    _ = f.GoToMarker(undefined, "6");
    _ = f.VerifyCurrentLineContent(undefined, "    public get Getter() { }");
    _ = f.GoToMarker(undefined, "7");
    _ = f.VerifyCurrentLineContent(undefined, "    public set Setter(x) { }");
    _ = f.GoToMarker(undefined, "8");
    _ = f.VerifyCurrentLineContent(undefined, "function foo() { { } }");
    _ = f.GoToMarker(undefined, "10");
    _ = f.VerifyCurrentLineContent(undefined, "(function() { });");
    _ = f.GoToMarker(undefined, "11");
    _ = f.VerifyCurrentLineContent(undefined, "(() => { });");
    _ = f.GoToMarker(undefined, "12");
    _ = f.VerifyCurrentLineContent(undefined, "var x: {};");
}

test "TestCompletionListInNamedClassExpression" {
    const content =
        \\var x = class myClass {
        \\   getClassName (){
        \\       m/*0*/
        \\   }
        \\   /*1*/
        \\}
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
//                     .Label =  "myClass",
//                     .Detail = undefined("(local class) myClass"),
//                     .Kind =   undefined(lsproto.CompletionItemKindProperty),
//                 },
//             },
//         },
//     });
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
}

test "TestJsdocPropTagCompletion" {
    const content =
        \\/**
        \\ * @typedef Foo
        \\ * @pr/**/
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
//                 "prop",
//             },
//         },
//     });
}

test "TestCodeFixMissingTypeAnnotationOnExports27_non_exported_bidings" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\let p = { x: 1, y: 2}
        \\const a = 1, b = 10, { x, y } = p, c = 1;
        \\export { x, y }
        \\export const d = a + b + c;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFixAll(undefined, .{
        .FixID = "fixMissingTypeAnnotationOnExports",
        .NewFileContent = "let p = { x: 1, y: 2}\nconst x: number = p.x;\nconst y: number = p.y;\nconst a = 1, b = 10, c = 1;\nexport { x, y }\nexport const d: number = a + b + c;",
    });
}

test "TestCompletionListObjectMembersInTypeLocationWithTypeof" {
    const content =
        \\// @strict: true
        \\const languageService = { getCompletions() {} }
        \\type A = Parameters<typeof languageService./*1*/>
        \\
        \\declare const obj: { dance: () => {} } | undefined
        \\type B = Parameters<typeof obj./*2*/>
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
//                     .Label =  "getCompletions",
//                     .Detail = undefined("(method) getCompletions(): void"),
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
//                     .Label =  "dance",
//                     .Detail = undefined("(property) dance: () => {}"),
//                 },
//             },
//         },
//     });
}

test "TestCodeFixAddVoidToPromise5" {
    const content =
        \\// @target: esnext
        \\// @lib: es2015
        \\// @strict: true
        \\const p4: Promise<number> = new Promise(resolve => resolve());
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCodeFixNotAvailable(undefined);
}

test "TestGoToModuleAliasDefinition" {
    const content =
        \\// @Filename: a.ts
        \\export class /*2*/Foo {}
        \\// @Filename: b.ts
        \\ import /*3*/n = require('a');
        \\ var x = new [|/*1*/n|].Foo();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestCompletionsECMAPrivateMember" {
    const content =
        \\// @target: esnext
        \\class K {
        \\  #value: number;
        \\
        \\  foo() {
        \\     this.#va/**/
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
//                 &.{
//                     .Label = "#value",
//                 },
//                 &.{
//                     .Label = "foo",
//                 },
//             },
//         },
//     });
}

test "TestFormattingDoubleLessThan" {
    const content =
        \\/*1*/if (<number>foo < <number>bar) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyCurrentLineContent(undefined, "if (<number>foo < <number>bar) { }");
}

test "TestQuickInfoLink9" {
    const content =
        \\type Foo = {
        \\    /**
        \\     * Text before {@link /**/a} text after
        \\     */
        \\    c: (a: number) => void;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestRenameModifiers" {
    const content =
        \\[|[|declare|] [|abstract|] class [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeDelta": -3 |}C1|] {
        \\    [|[|static|] [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeDelta": -2 |}a|];|]
        \\    [|[|readonly|] [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeDelta": -2 |}b|];|]
        \\    [|[|public|] [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeDelta": -2 |}c|];|]
        \\    [|[|protected|] [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeDelta": -2 |}d|];|]
        \\    [|[|private|] [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeDelta": -2 |}e|];|]
        \\}|]
        \\[|[|const|] enum [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeDelta": -2 |}E|] {
        \\}|]
        \\[|[|async|] function [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeDelta": -2 |}fn|]() {}|]
        \\[|[|export|] [|default|] class [|{| "isWriteAccess": true, "isDefinition": true, "contextRangeDelta": -3 |}C2|] {}|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRename(undefined, null , f.Ranges()[1], f.Ranges()[2], f.Ranges()[5], f.Ranges()[8], f.Ranges()[11], f.Ranges()[14], f.Ranges()[17], f.Ranges()[20], f.Ranges()[23], f.Ranges()[26], f.Ranges()[27]);
}

test "TestCompletionEntryForConst" {
    const content =
        \\const c = "s";
        \\/*1*/
        \\const d = 1
        \\d/*2*/
        \\const e = 1
        \\/*3*/
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
//                 &.{
//                     .Label =  "c",
//                     .Detail = undefined("const c: \"s\""),
//                     .Kind =   undefined(lsproto.CompletionItemKindVariable),
//                 },
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
//                 &.{
//                     .Label =  "d",
//                     .Detail = undefined("const d: 1"),
//                     .Kind =   undefined(lsproto.CompletionItemKindVariable),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"3"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "e",
//                     .Detail = undefined("const e: 1"),
//                     .Kind =   undefined(lsproto.CompletionItemKindVariable),
//                 },
//             },
//         },
//     });
}

test "TestGetOccurrencesIsDefinitionOfTypeAlias" {
    const content =
        \\/*1*/type /*2*/Alias= number;
        \\let n: /*3*/Alias = 12;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestJsdocTypedefTagNavigateTo" {
    const content =
        \\// @lib: es5
        \\// @allowNonTsExtensions: true
        \\// @Filename: jsDocTypedef_form2.js
        \\
        \\/** @typedef {(string | number)} NumberLike */
        \\/** @typedef {(string | number | string[])} */
        \\var NumberLike2;
        \\
        \\/** @type {/*1*/NumberLike} */
        \\var numberLike;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestExtendsTArray" {
    const content =
        \\// @strict: false
        \\interface I1<T> {
        \\    (a: T): T;
        \\}
        \\interface I2<T> extends I1<T[]> {
        \\    b: T;
        \\}
        \\var x: I2<Date>;
        \\var /**/y = x(undefined); // Typeof y should be Date[]
        \\y.length;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "var y: Date[]", "");
    _ = f.VerifyNoErrors(undefined);
}

test "TestThisPredicateFunctionCompletions03" {
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
        \\let leader/*13*/Status = a.isLeader();
        \\function isLeaderGuard(g: RoyalGuard) {
        \\   return g.isLeader();
        \\}
        \\let checked/*14*/LeaderStatus = isLeader/*15*/Guard(a);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"2", "6"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Unsorted = &.{
//                 "lead",
//                 "isLeader",
//                 "isFollower",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"4", "8"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Unsorted = &.{
//                 "follow",
//                 "isLeader",
//                 "isFollower",
//             },
//         },
//     });
}

test "TestGoToSource15_bundler" {
    const content =
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{ "compilerOptions": { "module": "esnext", "moduleResolution": "bundler", "lib": ["es5"] } }
        \\// @Filename: /home/src/workspaces/project/node_modules/react/package.json
        \\{ "name": "react", "version": "16.8.6", "main": "index.js" }
        \\// @Filename: /home/src/workspaces/project/node_modules/react/index.js
        \\'use strict';
        \\
        \\if (process.env.NODE_ENV === 'production') {
        \\  module.exports = require('./cjs/react.production.min.js');
        \\} else {
        \\  module.exports = require('./cjs/react.development.js');
        \\}
        \\// @Filename: /home/src/workspaces/project/node_modules/react/cjs/react.production.min.js
        \\'use strict';exports./*production*/useState=function(a){};exports.version='16.8.6';
        \\// @Filename: /home/src/workspaces/project/node_modules/react/cjs/react.development.js
        \\'use strict';
        \\if (process.env.NODE_ENV !== 'production') {
        \\  (function() {
        \\    function useState(initialState) {}
        \\    exports./*development*/useState = useState;
        \\    exports.version = '16.8.6';
        \\  }());
        \\}
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\import { [|/*start*/useState|] } from 'react';
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.VerifyBaselineGoToSourceDefinition(undefined, "start");
}

test "TestGetOccurrencesThrow7" {
    const content =
        \\try {
        \\    [|throw|] 10;
        \\
        \\    try {
        \\        throw 10;
        \\    }
        \\    catch (x) {
        \\        [|throw|] 10;
        \\    }
        \\    finally {
        \\        [|throw|] 10;
        \\    }
        \\}
        \\finally {
        \\    [|throw|] 10;
        \\}
        \\
        \\[|throw|] 10;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestInlayHintsReturnType" {
    const content =
        \\function foo1 () {
        \\    return 1
        \\}
        \\function foo2 (): number {
        \\    return 1
        \\}
        \\class C {
        \\    foo() {
        \\        return 1
        \\    }
        \\}
        \\const a = () => 1
        \\const b = function () { return 1 }
        \\const c = (b) => 1
        \\const d = b => 1
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayFunctionLikeReturnTypeHints = core.TSTrue}});
}

test "TestGenericMethodParam" {
    const content =
        \\class C<T> {
        \\    /*1*/
        \\}
        \\/*2*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
    _ = f.GoToMarker(undefined, "1");
    _ = f.InsertLine(undefined, "constructor(){}");
    _ = f.InsertLine(undefined, "foo(a: T) {");
    _ = f.InsertLine(undefined, "    return a;");
    _ = f.InsertLine(undefined, "}");
    _ = f.VerifyNoErrors(undefined);
    _ = f.GoToMarker(undefined, "2");
    _ = f.InsertLine(undefined, "var x = new C<number>();");
    _ = f.InsertLine(undefined, "var y: number = x.foo(5);");
    _ = f.VerifyNoErrors(undefined);
}

test "TestJsdocDeprecated_suggestion6" {
    const content =
        \\// @Filename: a.tsx
        \\/** @deprecated */
        \\type Props = {}
        \\/** @deprecated */
        \\const Component = (props: [|Props|]) => props && <div />;
        \\<[|Component|] old="old" new="new" />
        \\/** @deprecated */
        \\type Options = {}
        \\/** @deprecated */
        \\const deprecatedFunction = (options: [|Options|]) => { options }
        \\[|deprecatedFunction|]({});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "a.tsx");
    // f.VerifySuggestionDiagnostics(undefined, []*.{
//         .{
//             .Message = .{.String = undefined("'Props' is deprecated.")},
//             .Code =    &.{.Integer = undefined(int32(6385))},
//             .Range =   f.Ranges()[0].LSRange,
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//         },
//         .{
//             .Message = .{.String = undefined("'Component' is deprecated.")},
//             .Code =    &.{.Integer = undefined(int32(6385))},
//             .Range =   f.Ranges()[1].LSRange,
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//         },
//         .{
//             .Message = .{.String = undefined("'Options' is deprecated.")},
//             .Code =    &.{.Integer = undefined(int32(6385))},
//             .Range =   f.Ranges()[2].LSRange,
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//         },
//         .{
//             .Message = .{.String = undefined("'deprecatedFunction' is deprecated.")},
//             .Code =    &.{.Integer = undefined(int32(6385))},
//             .Range =   f.Ranges()[3].LSRange,
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//         },
//     });
}

test "TestInsertPublicBeforeSetter" {
    const content =
        \\class C {
        \\    /**/set Bar(bar:string) {}
        \\}
        \\var o2 = { set Foo(val:number) { } };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, "public ");
}

test "TestSmartSelection_functionParams1" {
    const content =
        \\function f(/*1*/p, /*2*/q?, /*3*/...r: any[] = []) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineSelectionRanges(undefined);
}

test "TestRegexErrorRecovery" {
    const content =
        \\ // test code
        \\//var x = //**/a/;/*1*/
        \\//x.exec("bab");
        \\ Bug 579071: Parser no longer detects a Regex when an open bracket is inserted
        \\verify.quickInfoIs("RegExp");
        \\verify.not.errorExistsAfterMarker("1");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.Insert(undefined, "(");
}

test "TestCompletionsNonExistentImport" {
    const content =
        \\import { NonExistentType } from "non-existent-module";
        \\let foo: /**/
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
//                 "NonExistentType",
//             },
//         },
//     });
}

test "TestImportNameCodeFixNewImportExportEqualsCommonJSInteropOn" {
    const content =
        \\// @Module: commonjs
        \\// @EsModuleInterop: true
        \\// @Filename: /foo.d.ts
        \\declare module "bar" {
        \\  const bar: number;
        \\  export = bar;
        \\}
        \\declare module "foo" {
        \\  const foo: number;
        \\  export = foo;
        \\}
        \\declare module "es" {
        \\  const es = 0;
        \\  export default es;
        \\}
        \\// @Filename: /a.ts
        \\import bar = require("bar");
        \\
        \\foo
        \\// @Filename: /b.ts
        \\foo
        \\// @Filename: /c.ts
        \\import es from "es";
        \\import bar = require("bar");
        \\
        \\foo
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/a.ts");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import bar = require(\"bar\");\nimport foo = require(\"foo\");\n\nfoo",
    }, null );
    _ = f.GoToFile(undefined, "/b.ts");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import foo from \"foo\";\n\nfoo",
    }, null );
    _ = f.GoToFile(undefined, "/c.ts");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import es from \"es\";\nimport bar = require(\"bar\");\nimport foo = require(\"foo\");\n\nfoo",
    }, null );
}

test "TestQuickInfoJSDocAtBeforeSpace" {
    const content =
        \\/**
        \\ * @return Don't @ me
        \\ */
        \\function /*f*/f() { }
        \\/**
        \\ * @return One final @
        \\ */
        \\function /*g*/g() { }
        \\/**
        \\ * @return An @
        \\ * But another line
        \\ */
        \\function /*h*/h() { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestCompletionListInClosedObjectTypeLiteralInSignature02" {
    const content =
        \\interface I<TString, TNumber> {
        \\    [s: string]: TString;
        \\    [s: number]: TNumber;
        \\}
        \\
        \\declare function foo<TString, TNumber>(obj: I<TString, TNumber>): { str: TStr/*1*/ }
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

test "TestImportStatementCompletions_quotes" {
    const content =
        \\// @Filename: /mod.ts
        \\export const foo = 0;
        \\// @Filename: /single.ts
        \\import * as fs from 'fs';
        \\[|import f/**/|]
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
//                     .Label =      "foo",
//                     .InsertText = undefined("import { foo$1 } from './mod';"),
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./mod",
//                         },
//                     },
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "foo",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestImportNameCodeFixUMDGlobalReact2" {
    const content =
        \\// @jsx: react
        \\// @jsxFactory: factory
        \\// @Filename: /factory.ts
        \\export function factory() { return {}; }
        \\declare global {
        \\    namespace JSX {
        \\        interface Element {}
        \\    }
        \\}
        \\// @Filename: /a.tsx
        \\[|<div/>|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/a.tsx");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { factory } from \"./factory\";\n\n<div/>",
    }, null );
}

test "TestCodeFixInferFromUsageRestParam" {
    const content =
        \\// @strict: false
        \\// @noImplicitAny: true
        \\function f(a: number, [|...rest |]){
        \\    a; rest;
        \\}
        \\f(1);
        \\f(2, "s1");
        \\f(3, "s1", "s2");
        \\f(3, "s1", "s2", "s3", "s4");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyRangeAfterCodeFix(undefined, "...rest: string[]", false, 0, 0);
}

test "TestCompletionsImport_notFromUnrelatedNodeModules" {
    const content =
        \\// @module: esnext
        \\// @Filename: /unrelated/node_modules/@types/foo/index.d.ts
        \\export function foo() {}
        \\// @Filename: /src/b.ts
        \\fo/**/;
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
//                 "foo",
//             },
//         },
//     });
}

test "TestAutoImportProvider_globalTypingsCache" {
    const content =
        \\// @Filename: /home/src/Library/Caches/typescript/node_modules/@types/react-router-dom/package.json
        \\ { "name": "@types/react-router-dom", "version": "16.8.4", "types": "index.d.ts" }
        \\// @Filename: /home/src/Library/Caches/typescript/node_modules/@types/react-router-dom/index.d.ts
        \\ export class BrowserRouterFromDts {}
        \\// @Filename: /home/src/workspaces/project/package.json
        \\ { "dependencies": { "react-router-dom": "*" } }
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\ { "compilerOptions": { "module": "commonjs", "lib": ["es5"], "allowJs": true, "checkJs": true, "maxNodeModuleJsDepth": 2 }, "typeAcquisition": { "enable": true } }
        \\// @Filename: /home/src/workspaces/project/node_modules/react-router-dom/package.json
        \\ { "name": "react-router-dom", "version": "16.8.4", "main": "index.js" }
        \\// @Filename: /home/src/workspaces/project/node_modules/react-router-dom/index.js
        \\ import "./BrowserRouter";
        \\ export {};
        \\// @Filename: /home/src/workspaces/project/node_modules/react-router-dom/BrowserRouter.js
        \\ export const BrowserRouterFromJs = () => null;
        \\// @Filename: /home/src/workspaces/project/index.js
        \\BrowserRouter/**/
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
//             .Exact = CompletionGlobalsInJSPlus(
//                 &.{
//                     &.{
//                         .Label = "BrowserRouterFromDts",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "react-router-dom",
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

test "TestGetOccurrencesThrow8" {
    const content =
        \\try {
        \\    throw 10;
        \\
        \\    try {
        \\        [|throw|] 10;
        \\    }
        \\    catch (x) {
        \\        throw 10;
        \\    }
        \\    finally {
        \\        throw 10;
        \\    }
        \\}
        \\finally {
        \\    throw 10;
        \\}
        \\
        \\throw 10;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestFindAllReferencesFromLinkTagReference5" {
    const content =
        \\enum E {
        \\    /** {@link E./**/A} */
        \\    A
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "");
}

test "TestCompletionsConditionalMember" {
    const content =
        \\declare function f<T extends string>(
        \\  p: { a: T extends 'foo' ? { x: string } : { y: string } }
        \\): void;
        \\
        \\f<'foo'>({ a: { /*1*/ } });
        \\f<string>({ a: { /*2*/ } });
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
//                     .Label = "x",
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
//                     .Label = "y",
//                 },
//             },
//         },
//     });
}

test "TestUnusedImports11FS" {
    const content =
        \\// @noUnusedLocals: true
        \\// @Filename: file2.ts
        \\[| import f1, * as s from "./file1"; |]
        \\s.f2('hello');
        \\// @Filename: file1.ts
        \\export var v1;
        \\export function f1(n: number){}
        \\export function f2(s: string){};
        \\export default f1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyRangeAfterCodeFix(undefined, "import * as s from \"./file1\";", false, 0, 0);
}

test "TestQuickInfoDisplayPartsFunctionIncomplete" {
    const content =
        \\/*1*/function /*2*/(param: string) {
        \\}\
        \\/*3*/function /*4*/ {
        \\}\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestJsdocThrowsTagCompletion" {
    const content =
        \\// @lib: es5
        \\/**
        \\ * @throws {/**/} description
        \\ */
        \\function fn() {}
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

test "TestCodeFixInferFromUsageMember3" {
    const content =
        \\// @noImplicitAny: true
        \\class C {
        \\    constructor([|public p)|] { }
        \\}
        \\new C("string");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyRangeAfterCodeFix(undefined, "public p: string)", false, 0, 0);
}

test "TestAutoImportProvider8" {
    const content =
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{ "compilerOptions": { "lib": ["es5"], "module": "commonjs" } }
        \\// @Filename: /home/src/workspaces/project/package.json
        \\{ "dependencies": { "mylib": "file:packages/mylib" } }
        \\// @Filename: /home/src/workspaces/project/packages/mylib/package.json
        \\{ "name": "mylib", "version": "1.0.0" }
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
    // f.Configure(undefined, opts1158);
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
    // f.VerifyApplyCodeActionFromCompletion(undefined, undefined("1"), &.{
//         .Name =          "MyClass",
//         .Source =        "mylib",
//         .Description =   "Add import from \"mylib\"",
//         .AutoImportFix = &.{},
//         .NewFileContent = undefined("import { MyClass } from \"mylib\";\n\nconst a = new MyClass();\nconst b = new MyClass2();"),
//     });
}

test "TestFindAllRefsForModule" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.ts
        \\export const x = 0;
        \\// @Filename: /b.ts
        \\[|import { x } from "/*0*/[|{| "contextRangeIndex": 0 |}./a|]";|]
        \\// @Filename: /c/sub.js
        \\[|const a = require("/*1*/[|{| "contextRangeIndex": 2 |}../a|]");|]
        \\// @Filename: /d.ts
        \\ /// <reference path="/*2*/[|./a.ts|]" />
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "0", "1", "2");
    // f.VerifyBaselineDocumentHighlightsWithOptions(undefined, null , &.{"/b.ts", "/c/sub.js", "/d.ts"}, f.Ranges()[1], f.Ranges()[3], f.Ranges()[4]);
}

test "TestCodeFixClassImplementInterfaceOptionalProperty" {
    const content =
        \\// @strict: false
        \\interface IPerson {
        \\    name: string;
        \\    birthday?: string;
        \\}
        \\class Person implements IPerson {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'IPerson'",
        .NewFileContent = "interface IPerson {\n    name: string;\n    birthday?: string;\n}\nclass Person implements IPerson {\n    name: string;\n    birthday?: string;\n}",
        .Index = 0,
    });
}

test "TestGoToDefinitionImportedNames10" {
    const content =
        \\// @allowjs: true
        \\// @Filename: a.js
        \\ class /*classDefinition*/Class {
        \\   f;
        \\ }
        \\ module.exports.Class = Class;
        \\// @Filename: b.js
        \\const { Class } = require("./a");
        \\ [|/*classAliasDefinition*/Class|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "classAliasDefinition");
}

test "TestQuickinfoExpressionTypeNotChangedViaDeletion" {
    const content =
        \\type TypeEq<A, B> = (<T>() => T extends A ? 1 : 2) extends (<T>() => T extends B ? 1 : 2) ? true : false;
        \\
        \\const /*2*/test1: TypeEq<number[], [number, ...number[]]> = false;
        \\
        \\declare const foo: [number, ...number[]];
        \\declare const bar: number[];
        \\
        \\const /*1*/test2: TypeEq<typeof foo, typeof bar> = false;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyQuickInfoIs(undefined, "const test2: false", "");
    _ = f.GoToMarker(undefined, "2");
    _ = f.VerifyQuickInfoIs(undefined, "const test1: false", "");
}

test "TestCodeFixMissingTypeAnnotationOnExports41_no_computed_enum_members" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\// @lib: es2019
        \\// @Filename: /code.ts
        \\enum E {
        \\    A = "foo".length
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCodeFixNotAvailable(undefined);
}

test "TestFormatSelectionWithTrivia5" {
    const content =
        \\if (true) {
        \\/*begin*/// test comment
        \\/*end*/    console.log();
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatSelection(undefined, "begin", "end");
    _ = f.VerifyCurrentFileContent(undefined, "if (true) {\n    // test comment\n    console.log();\n}");
}

test "TestAutoFormattingOnPasting" {
    const content =
        \\namespace TestModule {
        \\/**/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Paste(undefined, " class TestClass{\nprivate   foo;\npublic testMethod( )\n{}\n}");
    _ = f.VerifyCurrentFileContent(undefined, "namespace TestModule {\n    class TestClass {\n        private foo;\n        public testMethod() { }\n    }\n}");
}

test "TestCompletionsImport_filteredByPackageJson_peerDependencies" {
    const content =
        \\//@noEmit: true
        \\//@Filename: /package.json
        \\{
        \\  "peerDependencies": {
        \\    "react": "*"
        \\  }
        \\}
        \\//@Filename: /node_modules/react/index.d.ts
        \\export declare var React: any;
        \\//@Filename: /node_modules/react/package.json
        \\{
        \\  "name": "react",
        \\  "types": "./index.d.ts"
        \\}
        \\//@Filename: /node_modules/fake-react/index.d.ts
        \\export declare var ReactFake: any;
        \\//@Filename: /node_modules/fake-react/package.json
        \\{
        \\  "name": "fake-react",
        \\  "types": "./index.d.ts"
        \\}
        \\//@Filename: /src/index.ts
        \\const x = Re/**/
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
//                     .Label =               "React",
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "react",
//                         },
//                     },
//                     .SortText = undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//             .Excludes = &.{
//                 "ReactFake",
//             },
//         },
//     });
}

test "TestCompletionsKeyof" {
    const content =
        \\interface A { a: number; };
        \\interface B { a: number; b: number; };
        \\function f<T extends keyof A>(key: T) {}
        \\f("[|/*f*/|]");
        \\function g<T extends keyof B>(key: T) {}
        \\g("[|/*g*/|]");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "f", &.{
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
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "g", &.{
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
//                             .Range =   f.Ranges()[1].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label = "b",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "b",
//                             .Range =   f.Ranges()[1].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestFunctionTypeFormatting" {
    const content =
        \\var x: () =>           string/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, ";");
    _ = f.VerifyCurrentLineContent(undefined, "var x: () => string;");
}

test "TestGoToDefinitionSwitchCase6" {
    const content =
        \\export default { [|/*a*/case|] };
        \\[|/*b*/default|];
        \\[|/*c*/case|] 42;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "a", "b", "c");
}

test "TestNavigationBarAnonymousClassAndFunctionExpressions3" {
    const content =
        \\describe('foo', () => {
        \\    test(
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestCompletionListAtIdentifierDefinitionLocations_enums" {
    const content =
        \\var aa = 1;
        \\enum /*enumName1*/
        \\enum a/*enumName2*/
        \\var x = 0; enum /*enumName4*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, f.Markers(), null);
}

test "TestCodeFixAddParameterNames1" {
    const content =
        \\// @noImplicitAny: true
        \\var x: ([|number |]) => string;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyRangeAfterCodeFix(undefined, "arg0: number", false, 0, 0);
}

test "TestGetOccurrencesClassExpressionPublic" {
    const content =
        \\let A = class Foo {
        \\    [|public|] foo;
        \\    [|public|] public;
        \\    constructor([|public|] y: string, private x: string) {
        \\    }
        \\    [|public|] method() { }
        \\    private method2() {}
        \\    [|public|] static static() { }
        \\}
        \\
        \\let B = class D {
        \\    constructor(private x: number) {
        \\    }
        \\    private test() {}
        \\    public test2() {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestCodeFixInferFromUsageMember2" {
    const content =
        \\// @noImplicitAny: true
        \\interface I {
        \\    [|p;|]
        \\}
        \\var i: I;
        \\i.p = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyRangeAfterCodeFix(undefined, "p: number;", false, 0, 0);
}

test "TestGetOccurrencesIsWriteAccess" {
    const content =
        \\var [|{| "isWriteAccess": true |}x|] = 0;
        \\var assignmentRightHandSide = [|{| "isWriteAccess": false |}x|];
        \\var assignmentRightHandSide2 = 1 + [|{| "isWriteAccess": false |}x|];
        \\
        \\[|{| "isWriteAccess": true |}x|] = 1;
        \\[|{| "isWriteAccess": true |}x|] = [|{| "isWriteAccess": false |}x|] + [|{| "isWriteAccess": false |}x|];
        \\
        \\[|{| "isWriteAccess": false |}x|] == 1;
        \\[|{| "isWriteAccess": false |}x|] <= 1;
        \\
        \\var preIncrement = ++[|{| "isWriteAccess": true |}x|];
        \\var postIncrement = [|{| "isWriteAccess": true |}x|]++;
        \\var preDecrement = --[|{| "isWriteAccess": true |}x|];
        \\var postDecrement = [|{| "isWriteAccess": true |}x|]--;
        \\
        \\[|{| "isWriteAccess": true |}x|] += 1;
        \\[|{| "isWriteAccess": true |}x|] <<= 1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , f.Ranges()[0]);
}

test "TestCodeFixUnusedInterfaceInNamespace2" {
    const content =
        \\// @noUnusedLocals: true
        \\namespace greeter {
        \\    [| export interface interface2 {
        \\    }
        \\    interface interface1 {
        \\    } |]
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyRangeAfterCodeFix(undefined, "export interface interface2 {\n}", false, 0, 0);
}

test "TestQuickInfoOnElementAccessInWriteLocation3" {
    const content =
        \\// @strict: true
        \\// @exactOptionalPropertyTypes: true
        \\declare const xx: { prop?: number };
        \\xx['prop'/*1*/] ??= 1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "(property) prop?: number", "");
}

test "TestNoTypeParameterInLHS" {
    const content =
        \\interface I<T> { }
        \\class C<T> {}
        \\var /*1*/i: I<any>;
        \\var /*2*/c: C<I>;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "var i: I<any>", "");
    // f.VerifyQuickInfoAt(undefined, "2", "var c: C<any>", "");
}

test "TestAutoImportCrossProject_symlinks_stripSrc" {
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
        \\      "dep/*": ["../dep/src/*"]  
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
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { dep } from \"dep/sub/folder\";\n\ndep",
    }, null );
}

test "TestRefactorConvertToEsModule_module_nodenext" {
    const content =
        \\// @allowJs: true
        \\// @target: esnext
        \\// @module: node18
        \\// @Filename: /a.js
        \\module.exports = 0;
        \\// @Filename: /b.ts
        \\module.exports = 0;
        \\// @Filename: /c.cjs
        \\module.exports = 0;
        \\// @Filename: /d.cts
        \\module.exports = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/a.js");
    // f.VerifyCodeFixNotAvailable(undefined);
    _ = f.GoToFile(undefined, "/b.ts");
    // f.VerifyCodeFixNotAvailable(undefined);
    _ = f.GoToFile(undefined, "/c.cjs");
    // f.VerifyCodeFixNotAvailable(undefined);
    _ = f.GoToFile(undefined, "/d.cts");
    // f.VerifyCodeFixNotAvailable(undefined);
}

test "TestSyntacticClassificationsDocComment4" {
    const content =
        \\/** @param {number} p1 */
        \\function foo(p1) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "function.declaration", .Text = "foo"},
//         .{.Type = "parameter.declaration", .Text = "p1"},
//     });
}

test "TestInvertedCloduleAfterQuickInfo" {
    const content =
        \\// @strict: false
        \\namespace M {
        \\    namespace A {
        \\        var o;
        \\    }
        \\    class A {
        \\        /**/c
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyQuickInfoExists(undefined);
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
}

test "TestCompletionListInClosedObjectTypeLiteralInSignature03" {
    const content =
        \\interface I<TString, TNumber> {
        \\    [s: string]: TString;
        \\    [s: number]: TNumber;
        \\}
        \\
        \\declare function foo<TString, TNumber>(obj: I<TString, TNumber>): { str: TString/*1*/ }
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

test "TestGoToImplementationClassMethod_01" {
    const content =
        \\abstract class AbstractBar {
        \\    abstract he/*declaration*/llo(): void;
        \\}
        \\
        \\class Bar extends AbstractBar{
        \\    [|hello|]() {}
        \\}
        \\
        \\function whatever(x: AbstractBar) {
        \\    x.he/*reference*/llo();
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToImplementation(undefined, "reference", "declaration");
}

test "TestFormatSelectionDocCommentInBlock" {
    const content =
        \\{
        \\    /*1*//**
        \\     * Some doc comment
        \\     *//*2*/
        \\    const a = 1;
        \\}
        \\
        \\while (true) {
        \\/*3*//**
        \\ * Some doc comment
        \\ *//*4*/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatSelection(undefined, "1", "2");
    _ = f.VerifyCurrentFileContent(undefined, "{\n    /**\n     * Some doc comment\n     */\n    const a = 1;\n}\n\nwhile (true) {\n/**\n * Some doc comment\n */\n}");
    _ = f.FormatSelection(undefined, "3", "4");
    _ = f.VerifyCurrentFileContent(undefined, "{\n    /**\n     * Some doc comment\n     */\n    const a = 1;\n}\n\nwhile (true) {\n    /**\n     * Some doc comment\n     */\n}");
}

test "TestFormattingOnCloseBrace" {
    const content =
        \\class foo    {
        \\    /**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, "}");
    _ = f.GoToBOF(undefined);
    _ = f.VerifyCurrentLineContent(undefined, "class foo {");
}

test "TestGenericMapTyping1" {
    const content =
        \\// @strict: false
        \\interface Iterator_<T, U> {
        \\    (value: T, index: any, list: any): U;
        \\}
        \\interface WrappedArray<T> {
        \\    map<U>(iterator: Iterator_<T, U>, context?: any): U[];
        \\}
        \\interface Underscore {
        \\    <T>(list: T[]): WrappedArray<T>;
        \\    map<T, U>(list: T[], iterator: Iterator_<T, U>, context?: any): U[];
        \\}
        \\declare var _: Underscore;
        \\var aa: string[];
        \\var b/*1*/b = _.map(aa, x/*7*/x => xx.length);    // should be number[]
        \\var c/*2*/c = _(aa).map(x/*8*/x => xx.length);    // should be number[]
        \\var d/*3*/d = aa.map(xx => x/*9*/x.length);       // should be number[]
        \\var aaa: any[];
        \\var b/*4*/bb = _.map(aaa, xx => xx.length); // should be any[]
        \\var c/*5*/cc = _(aaa).map(xx => xx.length);  // Should not error, should be any[]
        \\var d/*6*/dd = aaa.map(xx => xx.length);     // should not error, should be any[]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
    // f.VerifyQuickInfoAt(undefined, "1", "var bb: number[]", "");
    // f.VerifyQuickInfoAt(undefined, "2", "var cc: number[]", "");
    // f.VerifyQuickInfoAt(undefined, "3", "var dd: number[]", "");
    // f.VerifyQuickInfoAt(undefined, "4", "var bbb: any[]", "");
    // f.VerifyQuickInfoAt(undefined, "5", "var ccc: any[]", "");
    // f.VerifyQuickInfoAt(undefined, "6", "var ddd: any[]", "");
    // f.VerifyQuickInfoAt(undefined, "7", "(parameter) xx: string", "");
    // f.VerifyQuickInfoAt(undefined, "8", "(parameter) xx: string", "");
    // f.VerifyQuickInfoAt(undefined, "9", "(parameter) xx: string", "");
}

test "TestCompletionsImport_uriStyleNodeCoreModules2" {
    const content =
        \\// @lib: es5
        \\// @module: commonjs
        \\// @Filename: /node_modules/@types/node/index.d.ts
        \\declare module "fs" { function writeFile(): void }
        \\declare module "fs/promises" { function writeFile(): Promise<void> }
        \\declare module "node:fs" { export * from "fs"; }
        \\declare module "node:fs/promises" { export * from "fs/promises"; }
        \\// @Filename: /other.ts
        \\import "node:fs/promises";
        \\// @Filename: /index.ts
        \\write/**/
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
//                         .Label = "writeFile",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "node:fs",
//                             },
//                         },
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     },
//                     &.{
//                         .Label = "writeFile",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "node:fs/promises",
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

test "TestCodeFixTopLevelAwait_module_missingCompilerOptionsInTsConfig" {
    const content =
        \\// @filename: /dir/a.ts
        \\declare const p: Promise<number>;
        \\await p;
        \\export {};
        \\// @filename: /dir/tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "module": "commonjs"
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCodeFixNotAvailable(undefined, "fixModuleOption");
}

test "TestTripleSlashRefPathCompletionRootdirs" {
    const content =
        \\// @rootDirs: sub/src1,src2
        \\// @Filename: src2/test0.ts
        \\/// <reference path="./mo/*0*/
        \\// @Filename: src2/module0.ts
        \\export var w = 0;
        \\// @Filename: sub/src1/module1.ts
        \\export var x = 0;
        \\// @Filename: sub/src1/module2.ts
        \\export var y = 0;
        \\// @Filename: sub/src1/more/module3.ts
        \\export var z = 0;
        \\// @Filename: f1.ts
        \\/*f1*/
        \\// @Filename: f2.tsx
        \\/*f2*/
        \\// @Filename: folder/f1.ts
        \\/*subf1*/
        \\// @Filename: f3.js
        \\/*f3*/
        \\// @Filename: f4.jsx
        \\/*f4*/
        \\// @Filename: e1.ts
        \\/*e1*/
        \\// @Filename: e2.js
        \\/*e2*/
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
//             .Exact = &.{
//                 "module0.ts",
//             },
//         },
//     });
}

test "TestQuickInfoJsDocTagsCallback" {
    const content =
        \\// @noEmit: true
        \\// @allowJs: true
        \\// @Filename: quickInfoJsDocTagsCallback.js
        \\/**
        \\ * @callback cb/*1*/
        \\ * @param {string} x - x comment
        \\ */
        \\
        \\/**
        \\ * @param {/*2*/cb} bar -callback comment
        \\ */
        \\function foo(bar) {
        \\    bar(bar);
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestNavigationBarItemsSymbols3" {
    const content =
        \\enum E {
        \\    // No nav bar entry for this
        \\    [Symbol.isRegExp] = 0
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestCompletionsRecommended_switch" {
    const content =
        \\enum Enu {}
        \\declare const e: Enu;
        \\switch (e) {
        \\    case E/*0*/:
        \\    case /*1*/:
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
//                     .Label =     "Enu",
//                     .Detail =    undefined("enum Enu"),
//                     .Kind =      undefined(lsproto.CompletionItemKindEnum),
//                     .Preselect = undefined(true),
//                 },
//             },
//         },
//     });
}

test "TestImportStatementCompletions_pnpmTransitive" {
    const content =
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{ "compilerOptions": { "module": "commonjs", "lib": ["es5"] } }
        \\// @Filename: /home/src/workspaces/project/node_modules/.pnpm/@types+react@17.0.7/node_modules/@types/react/index.d.ts
        \\import "csstype";
        \\export declare function Component(): void;
        \\// @Filename: /home/src/workspaces/project/node_modules/.pnpm/csstype@3.0.8/node_modules/csstype/index.d.ts
        \\export interface SvgProperties {}
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\[|import SvgProp/**/|]
        \\// @link: /home/src/workspaces/project/node_modules/.pnpm/@types+react@17.0.7/node_modules/@types/react -> /home/src/workspaces/project/node_modules/@types/react
        \\// @link: /home/src/workspaces/project/node_modules/.pnpm/csstype@3.0.8/node_modules/csstype -> /home/src/workspaces/project/node_modules/.pnpm/@types+react@17.0.7/node_modules/csstype
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToMarker(undefined, "");
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

test "TestRenameJsExports01" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\[|exports.[|{| "contextRangeIndex": 0 |}area|] = function (r) { return r * r; }|]
        \\// @Filename: b.js
        \\var mod = require('./a');
        \\var t = mod./*1*/[|area|](10);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1");
    // f.VerifyBaselineRenameAtRangesWithText(undefined, null , "area");
}

test "TestGetJavaScriptSyntacticDiagnostics10" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\function F<T>() { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineNonSuggestionDiagnostics(undefined);
}

test "TestRecursiveWrappedTypeParameters1" {
    const content =
        \\interface I<T> {
        \\    a: T;
        \\    b: I<T>;
        \\    c: I<I<T>>;
        \\}
        \\var x: I<number>;
        \\var y/*1*/y = x.c.c.c.c.c.b;
        \\var a/*2*/a = x.a;
        \\var b/*3*/b = x.b;
        \\var c/*4*/c = x.c;
        \\var d/*5*/d = x.c.a;
        \\var e/*6*/e = x.c.b;
        \\var f/*7*/f = x.c.c; 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "var yy: I<I<I<I<I<I<number>>>>>>", "");
    // f.VerifyQuickInfoAt(undefined, "2", "var aa: number", "");
    // f.VerifyQuickInfoAt(undefined, "3", "var bb: I<number>", "");
    // f.VerifyQuickInfoAt(undefined, "4", "var cc: I<I<number>>", "");
    // f.VerifyQuickInfoAt(undefined, "5", "var dd: I<number>", "");
    // f.VerifyQuickInfoAt(undefined, "6", "var ee: I<I<number>>", "");
    // f.VerifyQuickInfoAt(undefined, "7", "var ff: I<I<I<number>>>", "");
}

test "TestSemicolonFormatting" {
    const content =
        \\/**/function of1 (b:{r:{c:number
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToEOF(undefined);
    _ = f.Insert(undefined, ";");
    _ = f.VerifyCurrentLineContent(undefined, "function of1(b: { r: { c: number;");
}

test "TestRefactorConvertToEsModule_notAtTopLevel" {
    const content =
        \\// @allowJs: true
        \\// @target: esnext
        \\// @Filename: /a.js
        \\(function() {
        \\    module.exports = 0;
        \\})();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifySuggestionDiagnostics(undefined, null);
}

test "TestQuickInfoForObjectBindingElementName03" {
    const content =
        \\interface Options {
        \\    /**
        \\     * A description of foo
        \\     */
        \\    foo: string;
        \\}
        \\
        \\function f({ foo }: Options) {
        \\    foo/*1*/;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestCompletionListInTypeLiteralInTypeParameter5" {
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
        \\var foobar: Bar<{ prop1: string } & {/**/
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

test "TestGenericFunctionSignatureHelp3" {
    const content =
        \\function foo1<T>(x: number, callback: (y1: T) => number) { }
        \\function foo2<T>(x: number, callback: (y2: T) => number) { }
        \\function foo3<T>(x: number, callback: (y3: T) => number) { }
        \\function foo4<T>(x: number, callback: (y4: T) => number) { }
        \\function foo5<T>(x: number, callback: (y5: T) => number) { }
        \\function foo6<T>(x: number, callback: (y6: T) => number) { }
        \\function foo7<T>(x: number, callback: (y7: T) => number) { }
        \\ IDE shows the results on the right of each line, fourslash says different
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
    // f.VerifySignatureHelp(undefined, .{.Text = "foo1(x: number, callback: (y1: unknown) => number): void"});
    _ = f.GoToMarker(undefined, "2");
    // f.VerifySignatureHelp(undefined, .{.Text = "foo2(x: number, callback: (y2: unknown) => number): void"});
    _ = f.GoToMarker(undefined, "3");
    // f.VerifySignatureHelp(undefined, .{.Text = "callback(y3: unknown): number"});
    _ = f.GoToMarker(undefined, "4");
    // f.VerifySignatureHelp(undefined, .{.Text = "foo4(x: number, callback: (y4: string) => number): void"});
    _ = f.GoToMarker(undefined, "5");
    // f.VerifySignatureHelp(undefined, .{.Text = "callback(y5: string): number"});
    _ = f.GoToMarker(undefined, "6");
    // f.VerifySignatureHelp(undefined, .{.Text = "foo6(x: number, callback: (y6: unknown) => number): void"});
    _ = f.Insert(undefined, "string>(null,null);");
    _ = f.GoToMarker(undefined, "7");
    // f.VerifySignatureHelp(undefined, .{.Text = "foo7(x: number, callback: (y7: unknown) => number): void"});
}

test "TestCodeFixConvertToTypeOnlyImport2" {
    const content =
        \\// @module: esnext
        \\// @verbatimModuleSyntax: true
        \\// @Filename: exports.ts
        \\export default class A {}
        \\export class B {}
        \\export class C {}
        \\// @Filename: imports.ts
        \\import A, { B, C } from './exports';
        \\
        \\declare const a: A;
        \\declare const b: B;
        \\declare const c: C;
        \\console.log(a, b, c);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "imports.ts");
    // f.VerifyCodeFixNotAvailable(undefined);
}

test "TestQuickInfoFunctionCheckType" {
    const content =
        \\export type /**/Tail<T extends any[]> = ((...t: T) => void) extends (h: any, ...rest: infer R) => void ? R : never;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "type Tail<T extends any[]> = ((...t: T) => void) extends (h: any, ...rest: infer R) => void ? R : never", "");
}

test "TestCompletionListForNonExportedMemberInAmbientModuleWithExportAssignment1" {
    const content =
        \\// @Filename: completionListForNonExportedMemberInAmbientModuleWithExportAssignment1_file0.ts
        \\var x: Date;
        \\export = x;
        \\// @Filename: completionListForNonExportedMemberInAmbientModuleWithExportAssignment1_file1.ts
        \\///<reference path='completionListForNonExportedMemberInAmbientModuleWithExportAssignment1_file0.ts'/>
        \\ import test = require("completionListForNonExportedMemberInAmbientModuleWithExportAssignment1_file0");
        \\ test./**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, "", null);
}

test "TestFormatObjectBindingPattern_restElementWithPropertyName" {
    const content =
        \\const { ...a: b } = {};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.VerifyCurrentFileContent(undefined, "const { ...a: b } = {};");
}

test "TestQuickInfoCommentsFunctionDeclaration" {
    const content =
        \\/** This comment should appear for foo*/
        \\function f/*1*/oo() {
        \\}
        \\f/*2*/oo();
        \\/** This is comment for function signature*/
        \\function fo/*5*/oWithParameters(/** this is comment about a*/a: string,
        \\    /** this is comment for b*/
        \\    b: number) {
        \\    var /*6*/d = a;
        \\}
        \\fooWithParam/*8*/eters("a",10);
        \\/**
        \\* Does something
        \\* @param a a string
        \\*/
        \\declare function fn(a: string);
        \\fn("hello");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestCompletionListAfterStringLiteralTypeWithNoSubstitutionTemplateLiteral" {
    const content =
        \\let count: 'one' | 'two';
        \\count = 
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
//                     .Label = "one",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "one",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label = "two",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "two",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestFindAllRefsJsDocTemplateTag_function" {
    const content =
        \\/** @template /*1*/T */
        \\function f</*2*/T>() {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestGoToDefinitionObjectSpread" {
    const content =
        \\interface A1 { /*1*/a: number };
        \\interface A2 { /*2*/a?: number };
        \\let a1: A1;
        \\let a2: A2;
        \\let a12 = { ...a1, ...a2 };
        \\a12.[|a/*3*/|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "3");
}

test "TestCodeFixClassImplementInterfaceWithAmbientSignatures1" {
    const content =
        \\// @lib: esnext
        \\// @target: esnext
        \\// @Filename: /node_modules/@types/node/globals.d.ts
        \\export {};
        \\declare global {
        \\    interface SymbolConstructor {
        \\        readonly dispose: unique symbol;
        \\    }
        \\    interface Disposable {
        \\        [Symbol.dispose](): void;
        \\    }
        \\}
        \\// @Filename: /node_modules/@types/node/index.d.ts
        \\/// <reference path="globals.d.ts" />
        \\// @Filename: a.ts
        \\class Foo implements Disposable {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "a.ts");
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'Disposable'",
        .NewFileContent = "class Foo implements Disposable {\n    [Symbol.dispose](): void {\n        throw new Error(\"Method not implemented.\");\n    }\n}",
        .Index = 0,
    });
}

test "TestCompletionsLiteralDirectlyInRestConstrainedToTupleType" {
    const content =
        \\// @strict: true
        \\
        \\interface Func {
        \\  <Key extends "a" | "b">(
        \\    ...args:
        \\      | [key: Key, options?: any]
        \\      | [key: Key, defaultValue: string, options?: any]
        \\  ): string;
        \\}
        \\
        \\declare const func: Func;
        \\
        \\func("/*1*/");
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
//             .Exact = &.{
//                 "a",
//                 "b",
//             },
//         },
//     });
}

test "TestGetOccurrencesReadonly1" {
    const content =
        \\interface I {
        \\  [|readonly|] prop: string;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestCompletionForStringLiteral14" {
    const content =
        \\interface Foo {
        \\    a: string;
        \\    b: boolean;
        \\    c: number;
        \\}
        \\type Bar = Record<keyof Foo, any>["[|/**/|]"];
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
//                 &.{
//                     .Label = "c",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "c",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestGoToDefinitionSwitchCase3" {
    const content =
        \\switch (null) {
        \\  [|/*start1*/default|]: {
        \\    switch (null) {
        \\      [|/*start2*/default|]: break;
        \\    }
        \\  };
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "start1", "start2");
}

test "TestCompletionListAtIdentifierDefinitionLocations_varDeclarations" {
    const content =
        \\var aa = 1;
        \\var /*varName1*/
        \\var a/*varName2*/
        \\var a2,/*varName3*/
        \\var a2, a/*varName4*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, f.Markers(), null);
}

test "TestFormattingSpaceBeforeFunctionParen" {
    const content =
        \\/*1*/function foo() { }
        \\/*2*/function boo  () { }
        \\/*3*/var bar = function foo() { };
        \\/*4*/var foo = { bar() { } };
        \\/*5*/function tmpl <T> () { }
        \\/*6*/var f = function*() { };
        \\/*7*/function* g () { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.GetOptions();
    // f.Configure(undefined, opts333);
    // f.GetOptions();
    // f.Configure(undefined, opts414);
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyCurrentLineContent(undefined, "function foo () { }");
    _ = f.GoToMarker(undefined, "2");
    _ = f.VerifyCurrentLineContent(undefined, "function boo () { }");
    _ = f.GoToMarker(undefined, "3");
    _ = f.VerifyCurrentLineContent(undefined, "var bar = function foo () { };");
    _ = f.GoToMarker(undefined, "4");
    _ = f.VerifyCurrentLineContent(undefined, "var foo = { bar () { } };");
    _ = f.GoToMarker(undefined, "5");
    _ = f.VerifyCurrentLineContent(undefined, "function tmpl<T> () { }");
    _ = f.GoToMarker(undefined, "6");
    _ = f.VerifyCurrentLineContent(undefined, "var f = function*() { };");
    _ = f.GoToMarker(undefined, "7");
    _ = f.VerifyCurrentLineContent(undefined, "function* g () { }");
}

test "TestCompletionInIncompleteCallExpression" {
    const content =
        \\// @lib: es5
        \\var array = [1, 2, 4]
        \\function a4(x, y, z) { }
        \\a4(...<crash>/**/
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
//                     "a4",
//                     "array",
//                 }, false,
//             ),
//         },
//     });
}

test "TestCodeFixClassImplementInterfaceMultipleSignatures" {
    const content =
        \\interface I {
        \\    method(a: number, b: string): boolean;
        \\    method(a: string, b: number): Function;
        \\    method(a: string): Function;
        \\}
        \\
        \\class C implements I {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'I'",
        .NewFileContent = "interface I {\n    method(a: number, b: string): boolean;\n    method(a: string, b: number): Function;\n    method(a: string): Function;\n}\n\nclass C implements I {\n    method(a: number, b: string): boolean;\n    method(a: string, b: number): Function;\n    method(a: string): Function;\n    method(a: unknown, b?: unknown): boolean | Function {\n        throw new Error(\"Method not implemented.\");\n    }\n}",
        .Index = 0,
    });
}

test "TestRenameAlias3" {
    const content =
        \\namespace SomeModule { [|export class [|{| "contextRangeIndex": 0 |}SomeClass|] { }|] }
        \\import M = SomeModule;
        \\import C = M.[|SomeClass|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRenameAtRangesWithText(undefined, null , "SomeClass");
}

test "TestJsdocDeprecated_suggestion13" {
    const content =
        \\// @filename: foo.ts
        \\/**
        \\ * @deprecated
        \\ */
        \\function foo() {};
        \\
        \\class Foo {
        \\    constructor(fn: () => void) {
        \\        fn();
        \\    }
        \\}
        \\new Foo([|foo|]);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "foo.ts");
    // f.VerifySuggestionDiagnostics(undefined, []*.{
//         .{
//             .Code =    &.{.Integer = undefined(int32(6385))},
//             .Message = .{.String = undefined("'foo' is deprecated.")},
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//             .Range =   f.Ranges()[0].LSRange,
//         },
//     });
}

test "TestCompletionListInExportClause03" {
    const content =
        \\declare module "M1" {
        \\    export var abc: number;
        \\    export var def: string;
        \\}
        \\
        \\declare module "M2" {
        \\    export { abc/**/ } from "M1";
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
//                 "abc",
//                 "def",
//                 &.{
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestCodeFixUnreachableCode_noSuggestionIfDisabled" {
    const content =
        \\// @allowUnreachableCode: true
        \\if (false) [|0;|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifySuggestionDiagnostics(undefined, null);
}

test "TestReferencesForLabel5" {
    const content =
        \\/*1*/label:  while (true) {
        \\            if (false) /*2*/break /*3*/label;
        \\            function blah() {
        \\/*4*/label:          while (true) {
        \\                    if (false) /*5*/break /*6*/label;
        \\                }
        \\            }
        \\            if (false) /*7*/break /*8*/label;
        \\        }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5", "6", "7", "8");
}

test "TestCompletionListOnFunctionCallWithOptionalArgument" {
    const content =
        \\declare function Foo(arg1?: Function): { q: number };
        \\Foo(function () { } )./**/;
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
//                 "q",
//             },
//         },
//     });
}

test "TestCompletionListInObjectLiteralThatIsParameterOfFunctionCall" {
    const content =
        \\function f(a: { xa: number; xb: number; }) { }
        \\var xc;
        \\f({
        \\    /**/
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
//                 "xa",
//                 "xb",
//             },
//         },
//     });
}

