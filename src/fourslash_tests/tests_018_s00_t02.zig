const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestCompletionListBeforeKeyword" {
    const content =
        \\// Completion after dot in named type, when the following line has a keyword
        \\namespace TypeModule1 {
        \\    export class C1 {}
        \\    export class C2 {}
        \\}
        \\var x : TypeModule1./*TypeReference*/
        \\namespace TypeModule2 {
        \\    export class Test3 {}
        \\}
        \\
        \\// Completion after dot in named type, when the following line has a keyword
        \\TypeModule1./*ValueReference*/
        \\namespace TypeModule3 {
        \\    export class Test3 {}
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
//             .Exact = &.{
//                 "C1",
//                 "C2",
//             },
//         },
//     });
}

test "TestImportTypeMemberCompletions" {
    const content =
        \\// @Filename: /ns.ts
        \\export namespace Foo {
        \\    export namespace Bar {
        \\        export class Baz {}
        \\        export interface Bat {}
        \\        export const a: number;
        \\        const b: string;
        \\    }
        \\}
        \\// @Filename: /top.ts
        \\export interface Bat {}
        \\export const a: number;
        \\// @Filename: /equals.ts
        \\class Foo {
        \\ public static bar: string;
        \\ private static baz: number;
        \\}
        \\export = Foo;
        \\// @Filename: /usage1.ts
        \\type A = typeof import("./ns")./*1*/
        \\// @Filename: /usage2.ts
        \\type B = typeof import("./ns").Foo./*2*/
        \\// @Filename: /usage3.ts
        \\type C = typeof import("./ns").Foo.Bar./*3*/
        \\// @Filename: /usage4.ts
        \\type D = import("./ns")./*4*/
        \\// @Filename: /usage5.ts
        \\type E = import("./ns").Foo./*5*/
        \\// @Filename: /usage6.ts
        \\type F = import("./ns").Foo.Bar./*6*/
        \\// @Filename: /usage7.ts
        \\type G = typeof import("./top")./*7*/
        \\// @Filename: /usage8.ts
        \\type H = import("./top")./*8*/
        \\// @Filename: /usage9.ts
        \\type H = typeof import("./equals")./*9*/
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
//                 "Foo",
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
//                 "Bar",
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
//                 "a",
//                 "Baz",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "4", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "Foo",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "5", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "Bar",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "6", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "Bat",
//                 "Baz",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "7", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "a",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "8", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "Bat",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "9", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "bar",
//                 "prototype",
//             },
//         },
//     });
}

test "TestAutoImportProvider2" {
    const content =
        \\// @Filename: /home/src/workspaces/project/node_modules/direct-dependency/package.json
        \\{ "name": "direct-dependency", "dependencies": { "indirect-dependency": "*" } }
        \\// @Filename: /home/src/workspaces/project/node_modules/direct-dependency/index.d.ts
        \\import "indirect-dependency";
        \\export declare class DirectDependency {}
        \\// @Filename: /home/src/workspaces/project/node_modules/indirect-dependency/package.json
        \\{ "name": "indirect-dependency" }
        \\// @Filename: /home/src/workspaces/project/node_modules/indirect-dependency/index.d.ts
        \\export declare class IndirectDependency
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{ "compilerOptions": { "lib": ["es5"] } }
        \\// @Filename: /home/src/workspaces/project/package.json
        \\{ "dependencies": { "direct-dependency": "*" } }
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\IndirectDependency/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToMarker(undefined, "");
    // f.GetOptions();
    // f.Configure(undefined, opts1155);
    try f.VerifyImportFixAtPosition(undefined, &.{}, null );
}

test "TestTsxGoToDefinitionStatelessFunction1" {
    const content =
        \\//@Filename: file.tsx
        \\// @jsx: preserve
        \\// @noLib: true
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\    }
        \\    interface ElementAttributesProperty { props; }
        \\}
        \\interface OptionPropBag {
        \\    /*pt1*/propx: number
        \\    propString: "hell"
        \\    /*pt2*/optional?: boolean
        \\}
        \\declare function /*opt*/Opt(attributes: OptionPropBag): JSX.Element;
        \\let opt = <[|O/*one*/pt|] />;
        \\let opt1 = <[|Op/*two*/t|] [|pr/*p1*/opx|]={100} />;
        \\let opt2 = <[|Op/*three*/t|] propx={100} [|opt/*p2*/ional|] />;
        \\let opt3 = <[|Op/*four*/t|] wr/*p3*/ong />;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "one", "two", "three", "four", "p1", "p2");
}

test "TestRenameInheritedProperties6" {
    const content =
        \\interface C extends D {
        \\    propD: number;
        \\}
        \\interface D extends C {
        \\    [|[|{| "contextRangeIndex": 0 |}propC|]: number;|]
        \\}
        \\var d: D;
        \\d.[|propC|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null , "propC");
}

test "TestRenameJSDocNamepath" {
    const content =
        \\// @noLib: true
        \\/**
        \\ * @type {module:foo/A} x
        \\ */
        \\var x = 1
        \\var /*0*/A = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, null , "0");
}

test "TestImportNameCodeFixIndentedIdentifier" {
    const content =
        \\// @Filename: /a.ts
        \\[|import * as b from "./b";
        \\{
        \\    x/**/
        \\}|]
        \\// @Filename: /b.ts
        \\export const x = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import * as b from \"./b\";\n{\n    b.x\n}",
        "import * as b from \"./b\";\nimport { x } from \"./b\";\n{\n    x\n}",
    }, null );
}

test "TestImportTypeCompletions6" {
    const content =
        \\// @module: esnext
        \\// @Filename: /foo.ts
        \\export const foo = { };
        \\export interface Foo { };
        \\// @Filename: /bar.ts
        \\ [|import type * as f/**/|]
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

test "TestRenameFromNodeModulesDep3" {
    const content =
        \\// @Filename: /packages/first/index.d.ts
        \\import { /*ok*/[|Foo|] } from "foo";
        \\declare type FooBar = Foo[/*ok2*/"[|bar|]"];
        \\// @Filename: /packages/foo/package.json
        \\ { "types": "index.d.ts" }
        \\// @Filename: /packages/foo/index.d.ts
        \\export interface Foo {
        \\    /*ok3*/[|bar|]: string;
        \\}
        \\// @link: /packages/foo -> /packages/first/node_modules/foo
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "ok");
    // try f.VerifyRenameSucceeded(undefined, &.{.UseAliasesForRename = core.TSTrue});
    // try f.VerifyRenameSucceeded(undefined, &.{.UseAliasesForRename = core.TSFalse});
    _ = f.GoToMarker(undefined, "ok2");
    try f.VerifyRenameSucceeded(undefined, null );
    _ = f.GoToMarker(undefined, "ok3");
    try f.VerifyRenameSucceeded(undefined, null );
}

test "TestQuickInfoOnElementAccessInWriteLocation4" {
    const content =
        \\// @strict: true
        \\interface Serializer {
        \\  set value(v: string | number | boolean);
        \\  get value(): string;
        \\}
        \\declare let box: Serializer;
        \\box['value'/*1*/] = true;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "(property) Serializer.value: string | number | boolean", "");
}

