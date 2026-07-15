const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestRenameModuleExportsProperties1" {
    const content =
        \\[|class [|{| "contextRangeIndex": 0 |}A|] {}|]
        \\module.exports = { [|A|] }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRename(undefined, &.{.UseAliasesForRename = core.TSTrue}, f.Ranges()[1], f.Ranges()[2]);
}

test "TestQuickInfoFunctionKeyword" {
    const content =
        \\[1].forEach(fu/*1*/nction() {});
        \\[1].map(x =/*2*/> x + 1);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "(local function)(): void", "");
    // f.VerifyQuickInfoAt(undefined, "2", "function(x: number): number", "");
}

test "TestCompletionListAtEOF2" {
    const content =
        \\namespace Shapes {
        \\    export class Point {
        \\        constructor(public x: number, public y: number) { }
        \\    }
        \\}
        \\var p = <Shapes.
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToEOF(undefined);
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "Point",
//             },
//         },
//     });
}

test "TestFormattingNonNullAssertionOperator" {
    const content =
        \\/*1*/ 'bar' ! ;
        \\/*2*/ ( 'bar' ) ! ;
        \\/*3*/ 'bar' [ 1 ] ! ;
        \\/*4*/ var  bar  =  'bar' . foo ! ;
        \\/*5*/ var  foo  =  bar ! ;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    _ = f.VerifyCurrentLineContent(undefined, "'bar'!;");
    _ = f.GoToMarker(undefined, "2");
    _ = f.VerifyCurrentLineContent(undefined, "('bar')!;");
    _ = f.GoToMarker(undefined, "3");
    _ = f.VerifyCurrentLineContent(undefined, "'bar'[1]!;");
    _ = f.GoToMarker(undefined, "4");
    _ = f.VerifyCurrentLineContent(undefined, "var bar = 'bar'.foo!;");
    _ = f.GoToMarker(undefined, "5");
    _ = f.VerifyCurrentLineContent(undefined, "var foo = bar!;");
}

test "TestFindAllReferencesTripleSlash" {
    const content =
        \\// @checkJs: true
        \\// @Filename: /node_modules/@types/globals/index.d.ts
        \\declare const someAmbientGlobal: unknown;
        \\// @Filename: /a.ts
        \\/// <reference path="b.ts/*1*/" />
        \\/// <reference types="globals/*2*/" />
        \\// @Filename: /b.ts
        \\console.log("b.ts");
        \\// @Filename: /c.js
        \\require("./b");
        \\require("globals");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestQuickInfoOnThis3" {
    const content =
        \\interface Restricted {
        \\    n: number;
        \\}
        \\function implicitAny(x: number): void {
        \\    return th/*1*/is;
        \\}
        \\function explicitVoid(th/*2*/is: void, x: number): void {
        \\    return th/*3*/is;
        \\}
        \\function explicitInterface(th/*4*/is: Restricted): void {
        \\    console.log(thi/*5*/s);
        \\}
        \\function explicitLiteral(th/*6*/is: { n: number }): void {
        \\    console.log(th/*7*/is);
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "any", "");
    // f.VerifyQuickInfoAt(undefined, "2", "(parameter) this: void", "");
    // f.VerifyQuickInfoAt(undefined, "3", "this: void", "");
    // f.VerifyQuickInfoAt(undefined, "4", "(parameter) this: Restricted", "");
    // f.VerifyQuickInfoAt(undefined, "5", "this: Restricted", "");
    // f.VerifyQuickInfoAt(undefined, "6", "(parameter) this: {\n    n: number;\n}", "");
    // f.VerifyQuickInfoAt(undefined, "7", "this: {\n    n: number;\n}", "");
}

test "TestSyntacticClassificationForJSDocTemplateTag" {
    const content =
        \\/** @template T baring strait */
        \\function ident<T>: T {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "function.declaration", .Text = "ident"},
//         .{.Type = "typeParameter.declaration", .Text = "T"},
//         .{.Type = "typeParameter", .Text = "T"},
//     });
}

test "TestCompletionListInObjectLiteralAssignmentPattern2" {
    const content =
        \\let x = { a: 1, b: 2 };
        \\let y = ({ a, /**/ } = x, 1);
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

test "TestCompletionListAfterClassExtends" {
    const content =
        \\namespace Bar {
        \\    export class Bleah {
        \\    }
        \\    export class Foo extends /**/Bleah {
        \\    }
        \\}
        \\
        \\function Blah(x: Bar.Bleah) {
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
//                 "Bleah",
//                 "Foo",
//             },
//         },
//     });
}

test "TestGenericAssignmentCompat" {
    const content =
        \\interface Int<T> {
        \\
        \\    val<U>(f: (t: T) => U): Int<U>;
        \\
        \\}
        \\
        \\declare var v1: Int<string>;
        \\
        \\var /*1*/v2/*2*/: Int<number> = v1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyErrorExistsBetweenMarkers(undefined, "1", "2");
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
}

