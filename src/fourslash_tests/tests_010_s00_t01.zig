const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestOrganizeImportsType7" {
    const content =
        \\import { a, type A, b } from "foo";
        \\interface Use extends A {}
        \\console.log(a, b);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyOrganizeImports(undefined,
//         "import { a, type A, b } from \"foo\";\ninterface Use extends A {}\nconsole.log(a, b);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderInline,
//         },
//     );
    _ = f.ReplaceLine(undefined, 0, "import { a, type A, b } from \"foo1\";");
    // try f.VerifyOrganizeImports(undefined,
//         "import { a, type A, b } from \"foo1\";\ninterface Use extends A {}\nconsole.log(a, b);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSUnknown,
//             .OrganizeImportsTypeOrder =  lsutil.OrganizeImportsTypeOrderInline,
//         },
//     );
    _ = f.ReplaceLine(undefined, 0, "import { a, type A, b } from \"foo2\";");
    // try f.VerifyOrganizeImports(undefined,
//         "import { a, type A, b } from \"foo2\";\ninterface Use extends A {}\nconsole.log(a, b);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSTrue,
//             .OrganizeImportsTypeOrder =  lsutil.OrganizeImportsTypeOrderInline,
//         },
//     );
    _ = f.ReplaceLine(undefined, 0, "import { a, type A, b } from \"foo3\";");
    // try f.VerifyOrganizeImports(undefined,
//         "import { type A, a, b } from \"foo3\";\ninterface Use extends A {}\nconsole.log(a, b);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSFalse,
//             .OrganizeImportsTypeOrder =  lsutil.OrganizeImportsTypeOrderInline,
//         },
//     );
}

test "TestAutoImportFileExcludePatterns5" {
    const content =
        \\// @Filename: /src/vs/workbench/test.ts
        \\import { Parts } from './parts';
        \\export class /**/EditorParts implements Parts { }
        \\// @Filename: /src/vs/event/event.ts
        \\export interface Event {
        \\    (): string;
        \\}
        \\// @Filename: /src/vs/workbench/parts.ts
        \\import { Event } from '../event/event';
        \\export interface Parts {
        \\    readonly options: Event;
        \\}
        \\// @Filename: /src/vs/workbench/workbench.ts
        \\import { Event } from '../event/event';
        \\export { Event };
        \\// @Filename: /src/vs/workbench/canImport.ts
        \\import { Event } from '../event/event';
        \\export { Event };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'Parts'",
        .NewFileContent = "import { Event } from './canImport';\nimport { Parts } from './parts';\nexport class EditorParts implements Parts {\n    options: Event;\n}",
        .Index =           0,
        .UserPreferences = &.{.AutoImportFileExcludePatterns = &.{"src/vs/workbench/workbench.ts"}},
    });
}

test "TestCompletionListInTypeLiteralInTypeParameter8" {
    const content =
        \\interface Foo {
        \\    one: string;
        \\    two: {
        \\        three: {
        \\            four: number;
        \\            five: string;
        \\        }
        \\    }
        \\}
        \\
        \\interface Bar<T extends Foo> {
        \\    foo: T;
        \\}
        \\
        \\var foobar: Bar<{
        \\    two: {
        \\        three: {
        \\            five: string,
        \\            /*4*/
        \\        },
        \\        /*0*/
        \\    },
        \\    /*1*/
        \\}>;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "4", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "four",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "0", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{},
//         },
//     });
    // f.VerifyCompletions(undefined, "1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "one",
//             },
//         },
//     });
}

test "TestInlayHintsOverloadCall2" {
    const content =
        \\type HasID = {
        \\    id: number;
        \\}
        \\
        \\type Numbers = {
        \\    n: number[];
        \\}
        \\
        \\declare function func(bad1: number, bad2: HasID): void;
        \\declare function func(ok_1: Numbers, ok_2: HasID): void;
        \\
        \\func(
        \\    { n: [1, 2, 3] },
        \\    {
        \\        id: 1,
        \\    },
        \\);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayParameterNameHints = lsutil.IncludeInlayParameterNameHintsAll}});
}

test "TestImportNameCodeFix_importType1" {
    const content =
        \\// @verbatimModuleSyntax: true
        \\// @module: es2015
        \\// @Filename: /exports.ts
        \\export default someValue = 0;
        \\export function Component() {}
        \\export interface ComponentProps {}
        \\// @Filename: /a.ts
        \\import { Component } from "./exports.js";
        \\interface MoreProps extends /*a*/ComponentProps {}
        \\// @Filename: /b.ts
        \\import someValue from "./exports.js";
        \\interface MoreProps extends /*b*/ComponentProps {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "a");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { Component, type ComponentProps } from \"./exports.js\";\ninterface MoreProps extends ComponentProps {}",
    }, null );
    _ = f.GoToMarker(undefined, "b");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import someValue, { type ComponentProps } from \"./exports.js\";\ninterface MoreProps extends ComponentProps {}",
    }, null );
}

test "TestFindAllRefsInheritedProperties2" {
    const content =
        \\interface interface1 extends interface1 {
        \\   /*1*/doStuff(): void;   // r0
        \\   /*2*/propName: string;  // r1
        \\}
        \\
        \\var v: interface1;
        \\v./*3*/doStuff();  // r2
        \\v./*4*/propName;   // r3
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestHoverOverPrivateName" {
    const content =
        \\class A {
        \\    #f/*1*/oo = 3;
        \\    #b/*2*/ar: number;
        \\    #b/*3*/az = () => "hello";
        \\    #q/*4*/ux(n: number): string {
        \\        return "" + n;
        \\    }
        \\    static #staticF/*5*/oo = 3;
        \\    static #staticB/*6*/ar: number;
        \\    static #staticB/*7*/az = () => "hello";
        \\    static #staticQ/*8*/ux(n: number): string {
        \\        return "" + n;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "(property) A.#foo: number", "");
    try f.VerifyQuickInfoAt(undefined, "2", "(property) A.#bar: number", "");
    try f.VerifyQuickInfoAt(undefined, "3", "(property) A.#baz: () => string", "");
    try f.VerifyQuickInfoAt(undefined, "4", "(method) A.#qux(n: number): string", "");
    try f.VerifyQuickInfoAt(undefined, "5", "(property) A.#staticFoo: number", "");
    try f.VerifyQuickInfoAt(undefined, "6", "(property) A.#staticBar: number", "");
    try f.VerifyQuickInfoAt(undefined, "7", "(property) A.#staticBaz: () => string", "");
    try f.VerifyQuickInfoAt(undefined, "8", "(method) A.#staticQux(n: number): string", "");
}

test "TestCompletionListAfterAnyType" {
    const content =
        \\declare class myString {
        \\    charAt(pos: number): string;
        \\}
        \\
        \\function bar(a: myString) {
        \\    var x: any = a./**/
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
//                 "charAt",
//             },
//         },
//     });
}

test "TestGetJavaScriptSyntacticDiagnostics8" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\type a = b;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineNonSuggestionDiagnostics(undefined);
}

test "TestJsdocTypedefTagSemanticMeaning0" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\/** /*1*/@typedef {number} /*2*/T */
        \\/*3*/const /*4*/T = 1;
        \\/** @type {/*5*/T} */
        \\const n = /*6*/T;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5", "6");
}

