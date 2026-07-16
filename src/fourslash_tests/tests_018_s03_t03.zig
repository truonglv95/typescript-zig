const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestCompletionListInComments" {
    const content =
        \\var foo = '';
        \\( // f/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, "", null);
}

test "TestCompletionsWritingSpreadArgument" {
    const content =
        \\// @lib: es5
        \\
        \\const [] = [Math.min(./*marker*/)]
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.GoToMarker(undefined, "marker");
    _ = f.VerifyCompletions(undefined, null, null);
    _ = f.Insert(undefined, ".");
    _ = f.VerifyCompletions(undefined, null, null);
    _ = f.Insert(undefined, ".");
    // f.VerifyCompletions(undefined, null, &.{
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

test "TestQuickInfoInOptionalChain" {
    const content =
        \\// @strict: true
        \\interface A {
        \\  arr: string[];
        \\}
        \\
        \\function test(a?: A): string {
        \\  return a?.ar/*1*/r.length ? "A" : "B";
        \\}
        \\
        \\interface Foo { bar: { baz: string } };
        \\declare const foo: Foo | undefined;
        \\
        \\if (foo?.b/*2*/ar.b/*3*/az) {}
        \\
        \\interface Foo2 { bar?: { baz: { qwe: string } } };
        \\declare const foo2: Foo2;
        \\
        \\if (foo2.b/*4*/ar?.b/*5*/az.q/*6*/we) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "(property) A.arr: string[]", "");
    try f.VerifyQuickInfoAt(undefined, "2", "(property) Foo.bar: {\n    baz: string;\n}", "");
    try f.VerifyQuickInfoAt(undefined, "3", "(property) baz: string | undefined", "");
    try f.VerifyQuickInfoAt(undefined, "4", "(property) Foo2.bar?: {\n    baz: {\n        qwe: string;\n    };\n} | undefined", "");
    try f.VerifyQuickInfoAt(undefined, "5", "(property) baz: {\n    qwe: string;\n}", "");
    try f.VerifyQuickInfoAt(undefined, "6", "(property) qwe: string | undefined", "");
}

test "TestCodeFixConvertToTypeOnlyImport3" {
    const content =
        \\// @module: esnext
        \\// @verbatimModuleSyntax: true
        \\// @Filename: exports1.ts
        \\export default class A {}
        \\export class B {}
        \\export class C {}
        \\// @Filename: exports2.ts
        \\export default class D {}
        \\export class E {}
        \\export class F {}
        \\// @Filename: imports.ts
        \\import A, { B, C } from './exports1';
        \\import D, * as others from "./exports2";
        \\
        \\declare const a: A;
        \\declare const b: B;
        \\declare const c: C;
        \\declare const d: D;
        \\declare const o: typeof others;
        \\console.log(a, b, c, d, o);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "imports.ts");
    // try f.VerifyCodeFixNotAvailable(undefined);
}

test "TestGoToTypeDefinition" {
    const content =
        \\// @Filename: goToTypeDefinition_Definition.ts
        \\class /*definition*/C {
        \\    p;
        \\}
        \\var c: C;
        \\// @Filename: goToTypeDefinition_Consumption.ts
        \\/*reference*/c = undefined;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToTypeDefinition(undefined, "reference");
}

test "TestJsdocDeprecated_suggestion9" {
    const content =
        \\// @Filename: first.ts
        \\export class logger { }
        \\// @Filename: second.ts
        \\import { logger } from './first';
        \\new logger()
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "second.ts");
    try f.VerifyNoErrors(undefined);
    try f.VerifySuggestionDiagnostics(undefined, null);
}

test "TestReferencesForInheritedProperties" {
    const content =
        \\interface interface1 {
        \\    /*1*/doStuff(): void;
        \\}
        \\
        \\interface interface2  extends interface1{
        \\    /*2*/doStuff(): void;
        \\}
        \\
        \\class class1 implements interface2 {
        \\    /*3*/doStuff() {
        \\
        \\    }
        \\}
        \\
        \\class class2 extends class1 {
        \\
        \\}
        \\
        \\var v: class2;
        \\v./*4*/doStuff();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestRenamePrivateFields1" {
    const content =
        \\class Foo {
        \\   [|[|{| "contextRangeIndex": 0 |}#foo|] = 1;|]
        \\
        \\   getFoo() {
        \\       return this.[|#foo|];
        \\   }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null , "#foo");
}

test "TestPathCompletionsPackageJsonImportsOnlyFromClosestScope1" {
    const content =
        \\// @module: node18
        \\// @Filename: /package.json
        \\{
        \\  "imports": {
        \\    "#thing": "./src/something.ts"
        \\  }
        \\}
        \\// @Filename: /src/package.json
        \\{}
        \\// @Filename: /src/something.ts
        \\export function something(name: string): any;
        \\// @Filename: /src/a.ts
        \\import {} from "/*1*/";
        \\// @Filename: /a.ts
        \\import {} from "/*2*/";
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
//             .Exact = &.{},
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"2"}, &.{
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

test "TestRenameImportOfExportEquals2" {
    const content =
        \\[|declare namespace /*N*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 0 |}N|] {
        \\    export var x: number;
        \\}|]
        \\declare module "mod" {
        \\    [|export = [|{| "contextRangeIndex": 2 |}N|];|]
        \\}
        \\declare module "a" {
        \\    [|import * as /*O*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 4 |}O|] from "mod";|]
        \\    [|export { [|{| "contextRangeIndex": 6 |}O|] as /*P*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 6 |}P|] };|] // Renaming N here would rename
        \\}
        \\declare module "b" {
        \\    [|import { [|{| "contextRangeIndex": 9 |}P|] as /*Q*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 9 |}Q|] } from "a";|]
        \\    export const y: typeof [|Q|].x;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyNoErrors(undefined);
    // try f.VerifyBaselineFindAllReferences(undefined, "N", "O", "P", "Q");
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null , "N", "O", "P", "Q");
}

