const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestFindAllRefsUnionProperty" {
    const content =
        \\type T =
        \\    | { /*t0*/type: "a", /*p0*/prop: number }
        \\    | { /*t1*/type: "b", /*p1*/prop: string };
        \\const tt: T = {
        \\    /*t2*/type: "a",
        \\    /*p2*/prop: 0,
        \\};
        \\declare const t: T;
        \\if (t./*t3*/type === "a") {
        \\    t./*t4*/type;
        \\} else {
        \\    t./*t5*/type;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "t0", "t1", "t3", "t4", "t5", "t2", "p0", "p1", "p2");
}

test "TestTripleSlashRefPathCompletionContext" {
    const content =
        \\// @Filename: f.ts
        \\/*f*/
        \\// @Filename: test.ts
        \\/// <reference path/*0*/=/*1*/"/*8*/
        \\/// <reference path/*2*/=/*3*/"/*9*/"/*4*/ /*5*///*6*/>/*7*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, &.{"0", "1", "2", "3", "4", "5", "6", "7"}, null);
    // f.VerifyCompletions(undefined, &.{"8", "9"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "f.ts",
//             },
//         },
//     });
}

test "TestNavigationBarJsDocCommentWithNoTags" {
    const content =
        \\/** Test */
        \\export const Test = {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestCodeFixAddParameterNames3" {
    const content =
        \\// @noImplicitAny: true
        \\type Rest = ([|public string|]) => void;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyRangeAfterCodeFix(undefined, "public arg0: string", false, 0, 0);
}

test "TestCompletionsCombineOverloads_restParameter" {
    const content =
        \\interface A { a: number }
        \\interface B { b: number }
        \\interface C { c: number }
        \\declare function f(a: A): void;
        \\declare function f(...bs: B[]): void;
        \\declare function f(...cs: C[]): void;
        \\f({ /*1*/ });
        \\f({ a: 1 }, { /*2*/ });
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
//                 "a",
//                 "b",
//                 "c",
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
//                 "b",
//                 "c",
//             },
//         },
//     });
}

test "TestQuickInfoOnMergedInterfaces" {
    const content =
        \\namespace M {
        \\    interface A<T> {
        \\        (): string;
        \\        (x: T): T;
        \\    }
        \\    interface A<T> {
        \\        (x: T, y: number): T;
        \\        <U>(x: U, y: T): U;
        \\    }
        \\    var a: A<boolean>;
        \\    var r = a();
        \\    var r2 = a(true);
        \\    var r3 = a(true, 2);
        \\    var /*1*/r4 = a(1, true);
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "var r4: number", "");
}

test "TestReferencesForStringLiteralPropertyNames7" {
    const content =
        \\// @Filename: foo.js
        \\// @noEmit: true
        \\// @allowJs: true
        \\// @checkJs: true
        \\var x = { "/*1*/someProperty": 0 }
        \\x["/*2*/someProperty"] = 3;
        \\x.someProperty = 5;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestGoToDefinitionPropertyAssignment" {
    const content =
        \\export const /*FunctionResult*/Component = () => { return "OK"}
        \\Component./*PropertyResult*/displayName = 'Component'
        \\
        \\[|/*FunctionClick*/Component|]
        \\
        \\Component.[|/*PropertyClick*/displayName|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "FunctionClick", "PropertyClick");
}

test "TestFormattingOnConstructorSignature" {
    const content =
        \\/*1*/interface Gourai { new   () {} }
        \\/*2*/type Stylet = { new   () {} }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    // f.VerifyCurrentLineContent(undefined, "interface Gourai { new() { } }");
    _ = f.GoToMarker(undefined, "2");
    // f.VerifyCurrentLineContent(undefined, "type Stylet = { new() { } }");
}

test "TestAutoImportCrossPackage_pathsAndSymlink" {
    const content =
        \\// @Filename: /home/src/workspaces/project/packages/common/package.json
        \\{
        \\  "name": "@company/common",
        \\  "version": "1.0.0",
        \\  "main": "./lib/index.tsx"
        \\}
        \\// @Filename: /home/src/workspaces/project/packages/common/lib/index.tsx
        \\export function Tooltip {};
        \\// @Filename: /home/src/workspaces/project/packages/app/package.json
        \\{
        \\  "name": "@company/app",
        \\  "version": "1.0.0",
        \\  "dependencies": {
        \\    "@company/common": "1.0.0"
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/packages/app/tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "composite": true,
        \\    "lib": ["es5"],
        \\    "module": "esnext",
        \\    "moduleResolution": "bundler",
        \\    "paths": {
        \\      "@/*": ["./*"]
        \\    }
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/packages/app/lib/index.ts
        \\Tooltip/**/
        \\// @link: /home/src/workspaces/project/packages/common -> /home/src/workspaces/project/node_modules/@company/common
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToMarker(undefined, "");
    // f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"@company/common"}, null );
}

