const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestSignatureHelpInParenthetical" {
    const content =
        \\class base { constructor (public n: number, public y: string) { } }
        \\(new base(/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // try f.VerifySignatureHelp(undefined, .{.ParameterName = "n"});
    _ = f.Insert(undefined, "0, ");
    // try f.VerifySignatureHelp(undefined, .{.ParameterName = "y"});
}

test "TestImportNameCodeFix_barrelExport4" {
    const content =
        \\// @module: preserve
        \\// @moduleResolution: bundler
        \\// @Filename: /foo/a.ts
        \\export const A = 0;
        \\// @Filename: /foo/b.ts
        \\export {};
        \\A/*sibling*/
        \\// @Filename: /foo/index.ts
        \\export * from "./a";
        \\export * from "./b";
        \\// @Filename: /index.ts
        \\export * from "./foo";
        \\export * from "./src";
        \\// @Filename: /src/a.ts
        \\export {};
        \\A/*parent*/
        \\// @Filename: /src/index.ts
        \\export * from "./a";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyImportFixModuleSpecifiers(undefined, "sibling", &.{"./a", ".", ".."}, null );
    // try f.VerifyImportFixModuleSpecifiers(undefined, "parent", &.{"../foo", "../foo/a", ".."}, null );
}

test "TestGoToDefinitionJsDocImportTag5" {
    const content =
        \\// @allowJS: true
        \\// @checkJs: true
        \\// @Filename: /b.ts
        \\export interface /*2*/A { }
        \\// @Filename: /a.js
        \\/**
        \\ * @import { A } from "./b";
        \\ */
        \\
        \\/**
        \\ * @param { [|A/*1*/|] } a
        \\ */
        \\function f(a) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestJsdocPropertyTagCompletion" {
    const content =
        \\// @lib: es5
        \\/**
        \\ * @typedef {Object} Foo
        \\ * @property {/**/}
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
//             .Exact = CompletionGlobalTypes,
//         },
//     });
}

test "TestQuickInfoUnionOfNamespaces" {
    const content =
        \\declare const x: typeof A | typeof B;
        \\x./**/f;
        \\
        \\namespace A {
        \\    export function f() {}
        \\}
        \\namespace B {
        \\    export function f() {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "(method) f(): void", "");
}

test "TestCodeFixMissingTypeAnnotationOnExports26_fn_in_object_literal" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\export const extensions = {
        \\    /**
        \\     */
        \\    fn: <T>(actualValue: T, expectedValue: T) => {
        \\       return actualValue === expectedValue
        \\    },
        \\    fn2: function<T>(actualValue: T, expectedValue: T)  {
        \\       return actualValue === expectedValue
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFixAll(undefined, .{
        .FixID = "fixMissingTypeAnnotationOnExports",
        .NewFileContent = "export const extensions = {\n    /**\n     */\n    fn: <T>(actualValue: T, expectedValue: T): boolean => {\n       return actualValue === expectedValue\n    },\n    fn2: function<T>(actualValue: T, expectedValue: T): boolean  {\n       return actualValue === expectedValue\n    }\n}",
    });
}

test "TestQuickInfoForTypeofParameter" {
    const content =
        \\function foo() {
        \\    var y/*ref1*/1: string;
        \\    var x: typeof y/*ref2*/1;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "ref1", "(local var) y1: string", "");
    try f.VerifyQuickInfoAt(undefined, "ref2", "(local var) y1: string", "");
}

test "TestReferencesForGlobals2" {
    const content =
        \\// @Filename: referencesForGlobals_1.ts
        \\/*1*/class /*2*/globalClass {
        \\    public f() { }
        \\}
        \\// @Filename: referencesForGlobals_2.ts
        \\var c = /*3*/globalClass();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestGoToDefinitionInterfaceAfterImplement" {
    const content =
        \\interface /*interfaceDefinition*/sInt {
        \\    sVar: number;
        \\    sFn: () => void;
        \\}
        \\
        \\class iClass implements /*interfaceReference*/sInt {
        \\    public sVar = 1;
        \\    public sFn() {
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, false, "interfaceReference");
}

test "TestImportTypeCompletions3" {
    const content =
        \\// @target: esnext
        \\// @filename: /foo.ts
        \\export interface Foo {}
        \\// @filename: /bar.ts
        \\[|import type { F/**/ }|]
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
//                     .InsertText = undefined("import type { Foo } from \"./foo\";"),
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

