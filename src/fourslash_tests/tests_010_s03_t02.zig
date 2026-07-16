const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestCompletionsImport_reExportDefault2" {
    const content =
        \\// @lib: es5
        \\// @module: preserve
        \\// @checkJs: true
        \\// @Filename: /node_modules/example/package.json
        \\{ "name": "example", "version": "1.0.0", "main": "dist/index.js" }
        \\// @Filename: /node_modules/example/dist/nested/module.d.ts
        \\declare const defaultExport: () => void;
        \\declare const namedExport: () => void;
        \\
        \\export default defaultExport;
        \\export { namedExport };
        \\// @Filename: /node_modules/example/dist/index.d.ts
        \\export { default, namedExport } from "./nested/module";
        \\// @Filename: /index.mjs
        \\import { namedExport } from "example";
        \\defaultExp/**/
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
//             .Exact = CompletionGlobalsInJSPlus(
//                 &.{
//                     "namedExport",
//                     &.{
//                         .Label = "defaultExport",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "example",
//                             },
//                         },
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     },
//                 }, false,
//             ),
//         },
//     });
}

test "TestFormatObjectBindingPattern" {
    const content =
        \\const {
        \\x,
        \\y,
        \\} = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    try f.VerifyCurrentFileContent(undefined, "const {\n    x,\n    y,\n} = 0;");
}

test "TestImportNameCodeFix_barrelExport3" {
    const content =
        \\// @module: commonjs
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
    // try f.VerifyImportFixModuleSpecifiers(undefined, "sibling", &.{"./a", "./index", "../index"}, &.{.ImportModuleSpecifierEnding = "index"});
    // try f.VerifyImportFixModuleSpecifiers(undefined, "parent", &.{"../foo/a", "../foo/index", "../index"}, &.{.ImportModuleSpecifierEnding = "index"});
}

test "TestNavbar_contains_no_duplicates" {
    const content =
        \\declare namespace Windows {
        \\    export namespace Foundation {
        \\        export var A;
        \\        export class Test {
        \\            public wow();
        \\        }
        \\    }
        \\}
        \\
        \\declare namespace Windows {
        \\    export namespace Foundation {
        \\        export var B;
        \\        export namespace Test {
        \\            export function Boom(): number;
        \\        }
        \\    }
        \\}
        \\
        \\class ABC {
        \\    public foo() {
        \\        return 3;
        \\    }
        \\}
        \\
        \\namespace ABC {
        \\    export var x = 3;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestCodeFixConvertToTypeOnlyImport1" {
    const content =
        \\// @module: esnext
        \\// @verbatimModuleSyntax: true
        \\// @Filename: exports.ts
        \\export default class A {}
        \\export class B {}
        \\export class C {}
        \\// @Filename: imports.ts
        \\import {
        \\    B,
        \\    C,
        \\} from './exports';
        \\
        \\declare const b: B;
        \\declare const c: C;
        \\console.log(b, c);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "imports.ts");
    // try f.VerifyCodeFixNotAvailable(undefined);
}

test "TestQuickInfoInheritDoc" {
    const content =
        \\// @noEmit: true
        \\// @allowJs: true
        \\// @Filename: quickInfoInheritDoc.ts
        \\abstract class BaseClass {
        \\    /**
        \\     * Useful description always applicable
        \\     * 
        \\     * @returns {string} Useful description of return value always applicable.
        \\     */
        \\    public static doSomethingUseful(stuff?: any): string {
        \\        throw new Error('Must be implemented by subclass');
        \\    }
        \\
        \\    /**
        \\     * BaseClass.func1
        \\     * @param {any} stuff1 BaseClass.func1.stuff1
        \\     * @returns {void} BaseClass.func1.returns
        \\     */
        \\    public static func1(stuff1: any): void {
        \\    }
        \\
        \\    /**
        \\     * Applicable description always.
        \\     */
        \\    public static readonly someProperty: string = 'general value';
        \\}
        \\
        \\
        \\
        \\
        \\class SubClass extends BaseClass {
        \\
        \\    /**
        \\     * @inheritDoc
        \\     * 
        \\     * @param {{ tiger: string; lion: string; }} [mySpecificStuff] Description of my specific parameter.
        \\     */
        \\    public static /*1*/doSomethingUseful(mySpecificStuff?: { tiger: string; lion: string; }): string {
        \\        let useful = '';
        \\
        \\        // do something useful to useful
        \\
        \\        return useful;
        \\    }
        \\
        \\    /**
        \\     * @inheritDoc
        \\     * @param {any} stuff1 SubClass.func1.stuff1
        \\     * @returns {void} SubClass.func1.returns
        \\     */
        \\    public static /*2*/func1(stuff1: any): void {
        \\    }
        \\
        \\    /**
        \\     * text over tag
        \\     * @inheritDoc
        \\     * text after tag
        \\     */
        \\    public static readonly /*3*/someProperty: string = 'specific to this class value'
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestCodeFixMissingTypeAnnotationOnExports52_generics_oversimplification" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\export interface Foo<T, U = T[]> {}
        \\export function foo(x: Foo<string, string[]>) {
        \\    return x;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Add return type 'Foo<string>'",
        .NewFileContent = "export interface Foo<T, U = T[]> {}\nexport function foo(x: Foo<string, string[]>): Foo<string> {\n    return x;\n}",
        .Index = 0,
    });
}

test "TestCompletionForStringLiteralNonrelativeImport10" {
    const content =
        \\// @moduleResolution: classic
        \\// @Filename: dir1/dir2/dir3/dir4/test0.ts
        \\import * as foo1 from "f/*import_as0*/
        \\import * as foo3 from "fake-module/*import_as1*/
        \\import foo4 = require("f/*import_equals0*/
        \\import foo6 = require("fake-module/*import_equals1*/
        \\var foo7 = require("f/*require0*/
        \\var foo9 = require("fake-module/*require1*/
        \\// @Filename: package.json
        \\{ "dependencies": { "fake-module": "latest" } }
        \\// @Filename: node_modules/fake-module/ts.ts
        \\
        \\// @Filename: dir1/dir2/dir3/package.json
        \\{ "dependencies": { "fake-module3": "latest" } }
        \\// @Filename: dir1/dir2/dir3/node_modules/fake-module3/ts.ts
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, f.Markers(), &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{},
//         },
//     });
}

test "TestCompletionListAfterFunction" {
    const content =
        \\// Outside the function
        \\declare function f1(a: number);/*1*/
        \\
        \\// inside the function
        \\declare function f2(b: number, b2 = /*2*/
        \\
        \\// Outside the function
        \\function f3(c: number) { }/*3*/
        \\
        \\// inside the function
        \\function f4(d: number) { /*4*/}
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
//             .Excludes = &.{
//                 "a",
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
//             .Includes = &.{
//                 "b",
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
//             .Excludes = &.{
//                 "c",
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
//             .Includes = &.{
//                 "d",
//             },
//         },
//     });
}

test "TestDeleteTypeParameter" {
    const content =
        \\interface Query<T> {
        \\    groupBy(): Query</**/T>;
        \\}
        \\interface Query2<T> {
        \\    groupBy(): Query2<Query<T>>;
        \\}
        \\var q1: Query<number>;
        \\var q2: Query2<number>;
        \\q1 = q2;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.DeleteAtCaret(undefined, 1);
}

