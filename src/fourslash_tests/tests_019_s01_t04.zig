const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestGenericDerivedTypeAcrossModuleBoundary1" {
    const content =
        \\namespace M {
        \\   export class C1 { }
        \\   export class C2<T> { }
        \\}
        \\var c = new M.C2<number>();
        \\namespace N {
        \\   export class D1 extends M.C1 { }
        \\   export class D2<T> extends M.C2<T> { }
        \\}
        \\var n = new N.D1();
        \\var /*1*/n2 = new N.D2<number>();
        \\var /*2*/n3 = new N.D2();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "var n2: N.D2<number>", "");
    try f.VerifyQuickInfoAt(undefined, "2", "var n3: N.D2<unknown>", "");
}

test "TestFindAllRefsCommonJsRequire3" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\function f() { }
        \\module.exports = { f }
        \\// @Filename: /b.js
        \\const { f } = require('./a')
        \\/**/f
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "");
}

test "TestFindAllRefsExportEquals" {
    const content =
        \\// @Filename: /a.ts
        \\type /*0*/T = number;
        \\/*1*/export = /*2*/T;
        \\// @Filename: /b.ts
        \\import /*3*/T = require("/*4*/./a");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "0", "1", "2", "3", "4");
}

test "TestRestArgType" {
    const content =
        \\class Test {
        \\    private _priv(.../*1*/restArgs) {
        \\    }
        \\    public pub(.../*2*/restArgs) {
        \\        var x = restArgs[2];
        \\    }
        \\}
        \\var x: (...y: string[]) => void = function (.../*3*/y) {
        \\    var t = y;
        \\};
        \\function foo(x: (...y: string[]) => void ) { }
        \\foo((.../*4*/y1) => {
        \\    var t = y;
        \\});
        \\foo((/*5*/y2) => {
        \\    var t = y;
        \\});
        \\var t1 :(a1: string, a2: string) => void = (.../*t1*/f1) => { }  // f1 => any[];
        \\var t2: (a1: string, ...a2: string[]) => void = (.../*t2*/f1) => { } // f1 => any[];
        \\var t3: (a1: number, a2: boolean, ...c: string[]) => void  = (/*t31*/f1, .../*t32*/f2) => { }; // f1 => number, f2 => any[]
        \\var t4: (...a1: string[]) => void = (.../*t4*/f1) => { };      // f1 => string[]
        \\var t5: (...a1: string[]) => void = (/*t5*/f1) => { };         // f1 => string
        \\var t6: (...a1: string[]) => void = (/*t61*/f1, .../*t62*/f2) => { };  // f1 => string, f2 => string[]
        \\var t7: (...a1: string[]) => void = (/*t71*/f1, /*t72*/f2, /*t73*/f3) => { }; // fa => string, f2 => string, f3 => string
        \\// Explicit type annotation
        \\var t8: (...a1: string[]) => void = (/*t8*/f1: number[]) => { };
        \\// Explicit initialization value
        \\var t9: (a1: string[], a2: string[]) => void = (/*t91*/f1 = 4, /*t92*/f2 = [false, true]) => { };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "(parameter) restArgs: any[]", "");
    try f.VerifyQuickInfoAt(undefined, "2", "(parameter) restArgs: any[]", "");
    try f.VerifyQuickInfoAt(undefined, "3", "(parameter) y: string[]", "");
    try f.VerifyQuickInfoAt(undefined, "4", "(parameter) y1: string[]", "");
    try f.VerifyQuickInfoAt(undefined, "5", "(parameter) y2: string", "");
    try f.VerifyQuickInfoAt(undefined, "t1", "(parameter) f1: [a1: string, a2: string]", "");
    try f.VerifyQuickInfoAt(undefined, "t2", "(parameter) f1: [a1: string, ...a2: string[]]", "");
    try f.VerifyQuickInfoAt(undefined, "t31", "(parameter) f1: number", "");
    try f.VerifyQuickInfoAt(undefined, "t32", "(parameter) f2: [a2: boolean, ...c: string[]]", "");
    try f.VerifyQuickInfoAt(undefined, "t4", "(parameter) f1: string[]", "");
    try f.VerifyQuickInfoAt(undefined, "t5", "(parameter) f1: string", "");
    try f.VerifyQuickInfoAt(undefined, "t61", "(parameter) f1: string", "");
    try f.VerifyQuickInfoAt(undefined, "t62", "(parameter) f2: string[]", "");
    try f.VerifyQuickInfoAt(undefined, "t71", "(parameter) f1: string", "");
    try f.VerifyQuickInfoAt(undefined, "t72", "(parameter) f2: string", "");
    try f.VerifyQuickInfoAt(undefined, "t73", "(parameter) f3: string", "");
    try f.VerifyQuickInfoAt(undefined, "t8", "(parameter) f1: number[]", "");
    try f.VerifyQuickInfoAt(undefined, "t91", "(parameter) f1: string[]", "");
    try f.VerifyQuickInfoAt(undefined, "t92", "(parameter) f2: string[]", "");
}

test "TestIncrementalParsingTopLevelAwait2" {
    const content =
        \\// @target: esnext
        \\// @module: esnext
        \\// @Filename: ./foo.ts
        \\export {};
        \\/*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyNumberOfErrorsInCurrentFile(undefined, 0);
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, "await(1);");
    try f.VerifyNumberOfErrorsInCurrentFile(undefined, 0);
    _ = f.ReplaceLine(undefined, 1, "");
    try f.VerifyNumberOfErrorsInCurrentFile(undefined, 0);
}

test "TestUnusedImports9FS" {
    const content =
        \\// @noUnusedLocals: true
        \\// @Filename: file2.ts
        \\[|import c = require('./file1')|]
        \\// @Filename: file1.ts
        \\export class Calculator {
        \\    handleChar() { }
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
    try f.VerifyRangeAfterCodeFix(undefined, "", false, 0, 0);
}

test "TestCompletionsImport_default_addToNamespaceImport" {
    const content =
        \\// @Filename: /a.ts
        \\export default function foo() {}
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
    // try f.VerifyApplyCodeActionFromCompletion(undefined, undefined(""), &.{
//         .Name =        "foo",
//         .Source =      "./a",
//         .Description = "Update import from \"./a\"",
//         .NewFileContent = undefined("import foo, * as a from \"./a\";\nf;"),
//     });
}

test "TestMemberCompletionOnTypeParameters" {
    const content =
        \\interface IFoo {
        \\    x: number;
        \\    y: string;
        \\}
        \\
        \\function foo<S, T extends IFoo, U extends Object, V extends IFoo>() {
        \\    var s:S, t: T, u: U, v: V;
        \\    s./*S*/;    // no constraint, no completion
        \\    t./*T*/;    // IFoo
        \\    u./*U*/;    // IFoo
        \\    v./*V*/;    // IFoo
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, "S", null);
    // f.VerifyCompletions(undefined, &.{"T", "V"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =  "x",
//                     .Detail = undefined("(property) IFoo.x: number"),
//                 },
//                 &.{
//                     .Label =  "y",
//                     .Detail = undefined("(property) IFoo.y: string"),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "U", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Unsorted = &.{
//                 "constructor",
//                 "toString",
//                 "toLocaleString",
//                 "valueOf",
//                 "hasOwnProperty",
//                 "isPrototypeOf",
//                 "propertyIsEnumerable",
//             },
//         },
//     });
}

test "TestQuickInfoNamedTupleMembers" {
    const content =
        \\export type /*1*/Segment = [length: number, count: number];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "type Segment = [length: number, count: number]", "");
}

test "TestCompletionListInObjectBindingPattern05" {
    const content =
        \\interface I {
        \\    property1: number;
        \\    property2: string;
        \\}
        \\
        \\var foo: I;
        \\var { property1/**/ } = foo;
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
//                 "property1",
//                 "property2",
//             },
//         },
//     });
}

