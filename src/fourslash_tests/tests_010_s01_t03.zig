const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestFindAllRefsOfConstructor2" {
    const content =
        \\class A {
        \\    /*a*/constructor(s: string) {}
        \\}
        \\class B extends A {
        \\    /*b*/constructor() { super(""); }
        \\}
        \\class C extends B {
        \\    /*c*/constructor() {
        \\        super();
        \\    }
        \\}
        \\class D extends B { }
        \\const a = new A("a");
        \\const b = new B();
        \\const c = new C();
        \\const d = new D();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyNoErrors(undefined);
    // try f.VerifyBaselineFindAllReferences(undefined, "a", "b", "c");
}

test "TestFindAllRefsForDefaultExport01" {
    const content =
        \\/*1*/export default class /*2*/DefaultExportedClass {
        \\}
        \\
        \\var x: /*3*/DefaultExportedClass;
        \\
        \\var y = new /*4*/DefaultExportedClass;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestDocCommentTemplateConstructor01" {
    const content =
        \\class C {
        \\    private p;
        \\    /*0*/
        \\    constructor(a, b, c, d);
        \\    /*1*/
        \\    constructor(public a, private b, protected c, d, e?) {
        \\    }
        \\
        \\    foo();
        \\    foo(a?, b?, ...args) {
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyJSDocCompletion(undefined, "0", 11, "/**\n     * \n     * @param a\n     * @param b\n     * @param c\n     * @param d\n     */", null);
    // try f.VerifyJSDocCompletion(undefined, "1", 11, "/**\n     * \n     * @param a\n     * @param b\n     * @param c\n     * @param d\n     * @param e\n     */", null);
}

test "TestGoToDefinitionOverriddenMember22" {
    const content =
        \\// @strict: true
        \\// @target: esnext
        \\// @lib: esnext
        \\const prop = "foo" as const;
        \\
        \\abstract class A {}
        \\
        \\export class B extends A {
        \\  [|/*1*/override|] readonly [prop] = "B";
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestImportCompletions_importsMap2" {
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
        \\import {} from "/*1*/";
        \\import {} from "#internal//*2*/";
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
//                 "#internal",
//             },
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
//                 "foo.js",
//             },
//         },
//     });
}

test "TestCompletionsRecursiveNamespace" {
    const content =
        \\declare namespace N {
        \\    export import M = N;
        \\}
        \\type T = N./**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, "", null);
}

test "TestSemanticModernClassificationCallableVariables2" {
    const content =
        \\import "node";
        \\var fs = require("fs")
        \\require.resolve('react');
        \\require.resolve.paths;
        \\interface LanguageMode { getFoldingRanges?: (d: string) => number[]; };
        \\function (mode: LanguageMode | undefined) { if (mode && mode.getFoldingRanges) { return mode.getFoldingRanges('a'); }};
        \\function b(a: () => void) { a(); };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "variable.declaration", .Text = "fs"},
//         .{.Type = "interface.declaration", .Text = "LanguageMode"},
//         .{.Type = "method.declaration", .Text = "getFoldingRanges"},
//         .{.Type = "parameter.declaration", .Text = "d"},
//         .{.Type = "parameter.declaration", .Text = "mode"},
//         .{.Type = "interface", .Text = "LanguageMode"},
//         .{.Type = "parameter", .Text = "mode"},
//         .{.Type = "parameter", .Text = "mode"},
//         .{.Type = "method", .Text = "getFoldingRanges"},
//         .{.Type = "parameter", .Text = "mode"},
//         .{.Type = "method", .Text = "getFoldingRanges"},
//         .{.Type = "function.declaration", .Text = "b"},
//         .{.Type = "function.declaration", .Text = "a"},
//         .{.Type = "function", .Text = "a"},
//     });
}

test "TestCodeFixClassImplementInterfaceTypeParamMethod" {
    const content =
        \\interface I {
        \\    f<T extends number>(x: T): T;
        \\}
        \\class C implements I {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'I'",
        .NewFileContent = "interface I {\n    f<T extends number>(x: T): T;\n}\nclass C implements I {\n    f<T extends number>(x: T): T {\n        throw new Error(\"Method not implemented.\");\n    }\n}",
        .Index = 0,
    });
}

test "TestAutoImportPackageJsonImportsLength1" {
    const content =
        \\// @module: node18
        \\// @Filename: /package.json
        \\{
        \\  "imports": {
        \\    "#*": "./src/*.ts"
        \\  }
        \\}
        \\// @Filename: /src/a/b/c/something.ts
        \\export function something(name: string): any;
        \\// @Filename: /src/a/b/c/d.ts
        \\something/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"./something"}, null );
}

test "TestFormattingForIn" {
    const content =
        \\/**/for (var i    in[]   )  {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "");
    try f.VerifyCurrentLineContent(undefined, "for (var i in []) { }");
}

