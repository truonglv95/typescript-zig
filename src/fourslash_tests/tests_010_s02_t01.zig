const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestFormattingOnSemiColon" {
    const content =
        \\var  a=b+c^d-e*++f
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToEOF(undefined);
    _ = f.Insert(undefined, ";");
    try f.VerifyCurrentFileContent(undefined, "var a = b + c ^ d - e * ++f;");
}

test "TestImportNameCodeFixExportAsDefaultExistingImport" {
    const content =
        \\import [|{ v1, v2, v3 }|] from "./module";
        \\v4/*0*/();
        \\// @Filename: module.ts
        \\const v4 = 5;
        \\export { v4 as default };
        \\export const v1 = 5;
        \\export const v2 = 5;
        \\export const v3 = 5;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyImportFixAtPosition(undefined, &.{
        "v4, { v1, v2, v3 }",
    }, null );
}

test "TestCompletionWithConditionalOperatorMissingColon" {
    const content =
        \\1 ? fun/*1*/
        \\function func () {}
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
//                 "func",
//             },
//         },
//     });
}

test "TestGenericInterfacesWithConstraints1" {
    const content =
        \\interface A { a: string; }
        \\interface B extends A { b: string; }
        \\interface C extends B { c: string; }
        \\interface G<T, U extends B> {
        \\    x: T;
        \\    y: U;
        \\}
        \\var v/*1*/1: G<A, C>;               // Ok
        \\var v/*2*/2: G<{ a: string }, C>;   // Ok, equivalent to G<A, C>
        \\var v/*3*/3: G<G<A, B>, C>;         // Ok
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "var v1: G<A, C>", "");
    try f.VerifyQuickInfoAt(undefined, "2", "var v2: G<{\n    a: string;\n}, C>", "");
    try f.VerifyQuickInfoAt(undefined, "3", "var v3: G<G<A, B>, C>", "");
}

test "TestCodeFixClassImplementInterfaceMethodThisAndSelfReference" {
    const content =
        \\interface I {
        \\    f(x: number, y: this): I
        \\}
        \\
        \\class C implements I {[| |]}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'I'",
        .NewFileContent = "interface I {\n    f(x: number, y: this): I\n}\n\nclass C implements I {\n    f(x: number, y: this): I {\n        throw new Error(\"Method not implemented.\");\n    }\n}",
        .Index = 0,
    });
}

test "TestDocumentHighlights02" {
    const content =
        \\// @lib: es5
        \\// @Filename: a.ts
        \\function [|foo|] () {
        \\    return 1;
        \\}
        \\[|foo|]();
        \\// @Filename: b.ts
        \\/// <reference path="a.ts"/>
        \\[|foo|]();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToFile(undefined, "a.ts");
    _ = f.GoToFile(undefined, "b.ts");
    // try f.VerifyBaselineDocumentHighlightsWithOptions(undefined, null , &.{"a.ts", "b.ts"}, ToAny(f.Ranges()));
}

test "TestSmartSelection_function2" {
    const content =
        \\function f2() {
        \\    /**/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSelectionRanges(undefined);
}

test "TestFindAllRefsReExportsUseInImportType" {
    const content =
        \\// @Filename: /foo/types/types.ts
        \\[|export type /*full0*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 0 |}Full|] = { prop: string; };|]
        \\// @Filename: /foo/types/index.ts
        \\[|import * as /*foo0*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 2 |}foo|] from './types';|]
        \\[|export { /*foo1*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 4 |}foo|] };|]
        \\// @Filename: /app.ts
        \\[|import { /*foo2*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 6 |}foo|] } from './foo/types';|]
        \\export type fullType = /*foo3*/[|foo|]./*full1*/[|Full|];
        \\type namespaceImport = typeof import('./foo/types');
        \\type fullType2 = import('./foo/types')./*foo4*/[|foo|]./*full2*/[|Full|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyNoErrors(undefined);
    // try f.VerifyBaselineFindAllReferences(undefined, "full0", "full1", "full2", "foo0", "foo1", "foo2", "foo3", "foo4");
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[1], f.Ranges()[9], f.Ranges()[11]);
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[3]);
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[5], f.Ranges()[10]);
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[7], f.Ranges()[8]);
    // try f.VerifyBaselineRename(undefined, &.{.UseAliasesForRename = core.TSFalse}, f.Ranges()[7], f.Ranges()[8], f.Ranges()[10], f.Ranges()[3], f.Ranges()[5]);
}

test "TestQuickInfoPrivateIdentifierInTypeReferenceNoCrash1" {
    const content =
        \\// @target: esnext
        \\class Foo {
        \\  #prop: string = "";
        \\
        \\  method() {
        \\    const test: Foo.#prop/*1*/ = "";
        \\  }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "", "");
}

test "TestImportNameCodeFix_shorthandPropertyAssignment2" {
    const content =
        \\// @Filename: /a.ts
        \\const a = 1;
        \\export default a;
        \\// @Filename: /b.ts
        \\const b = { /**/a };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/b.ts");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import a from \"./a\";\n\nconst b = { a };",
    }, null );
}

