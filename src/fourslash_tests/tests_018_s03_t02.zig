const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestDocCommentTemplateExportAssignmentJS" {
    const content =
        \\// @allowJs: true
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: index.js
        \\/** /**/ */
        \\exports.foo = (a) => {};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyJSDocCompletion(undefined, "", 7, "/**\n * \n * @param {any} a\n */", null);
}

test "TestNodeNextModuleKindCaching1" {
    const content =
        \\// @Filename: tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\      "lib": ["es5"],
        \\      "rootDir": "src",
        \\      "outDir": "dist",
        \\      "target": "ES2020",
        \\      "module": "NodeNext",
        \\      "strict": true
        \\    },
        \\    "include": ["src\\**\\*.ts"]
        \\}
        \\// @Filename: package.json
        \\{
        \\    "type": "module",
        \\    "private": true
        \\}
        \\// @Filename: src/index.ts
        \\// The line below should show a "Relative import paths need explicit file
        \\// extensions..." error in VS Code, but it doesn't. The error is only picked up
        \\// by 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
}

test "TestGoToDefinition_super" {
    const content =
        \\class A {
        \\    /*ctr*/constructor() {}
        \\    x() {}
        \\}
        \\class /*B*/B extends A {}
        \\class C extends B {
        \\    constructor() {
        \\        [|/*super*/super|]();
        \\    }
        \\    method() {
        \\        [|/*superExpression*/super|].x();
        \\    }
        \\}
        \\class D {
        \\    constructor() {
        \\        /*superBroken*/super();
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "super", "superExpression", "superBroken");
}

test "TestQuickInfoJSDocFunctionThis" {
    const content =
        \\// @allowJs: true
        \\// @Filename: Foo.js
        \\/** @type {function (this: string, string): string} */
        \\var f/**/ = function (s) { return s; }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyQuickInfoIs(undefined, "var f: (this: string, arg1: string) => string", "");
}

test "TestFindAllRefsOnImportAliases" {
    const content =
        \\//@Filename: a.ts
        \\export class /*0*/Class {
        \\}
        \\//@Filename: b.ts
        \\import { /*1*/Class } from "./a";
        \\
        \\var c = new /*2*/Class();
        \\//@Filename: c.ts
        \\export { /*3*/Class } from "./a";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "0", "1", "2");
}

test "TestQuickInfoTypeArgumentInferenceWithMethodWithoutBody" {
    const content =
        \\interface ProxyHandler<T extends object> {
        \\    getPrototypeOf?(target: T): object | null;
        \\}
        \\interface ProxyConstructor {
        \\    new <T extends object>(target: T, handler: ProxyHandler<T>): T;
        \\}
        \\declare var Proxy: ProxyConstructor;
        \\let target = {}
        \\let proxy = new /**/Proxy(target, {
        \\    getPrototypeOf()
        \\})
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyQuickInfoExists(undefined);
}

test "TestCompletionsNamespaceMergedWithClass" {
    const content =
        \\// @lib: es5
        \\class C {
        \\    static m() { }
        \\}
        \\
        \\class D extends C {}
        \\namespace D {
        \\    export type T = number;
        \\}
        \\
        \\let x: D./*type*/;
        \\D./*value*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "type", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "T",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "value", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionFunctionMembersPlus(
//                 &.{
//                     &.{
//                         .Label =    "m",
//                         .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                     },
//                     &.{
//                         .Label =    "prototype",
//                         .SortText = undefined(string(ls.SortTextLocationPriority)),
//                     },
//                 },
//             ),
//         },
//     });
}

test "TestAutoImportPackageJsonImportsPattern_ts_js" {
    const content =
        \\// @module: node18
        \\// @Filename: /package.json
        \\{
        \\  "imports": {
        \\    "#*.ts": "./src/*.js"
        \\  }
        \\}
        \\// @Filename: /src/something.ts
        \\export function something(name: string): any;
        \\// @Filename: /a.ts
        \\something/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"#something.ts"}, null );
}

test "TestGoToDefinitionOverriddenMember15" {
    const content =
        \\// @noImplicitOverride: true
        \\class A {
        \\    static /*2*/m() {}
        \\}
        \\class B extends A {}
        \\class C extends B {
        \\    static [|/*1*/override|] m() {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestCompletionsWithOptionalPropertiesGenericValidBoolean" {
    const content =
        \\// @strict: true
        \\interface MyOptions {
        \\    hello?: boolean;
        \\    world?: boolean;
        \\}
        \\declare function bar<T extends MyOptions>(options?: Partial<T>): void;
        \\bar({ hello: true, /*1*/ });
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

