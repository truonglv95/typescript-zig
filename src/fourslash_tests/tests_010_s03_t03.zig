const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestNavigationBarItemsInsideMethodsAndConstructors" {
    const content =
        \\class Class {
        \\    constructor() {
        \\        function LocalFunctionInConstructor() {}
        \\        interface LocalInterfaceInConstrcutor {}
        \\        enum LocalEnumInConstructor { LocalEnumMemberInConstructor }
        \\    }
        \\
        \\    method() {
        \\        function LocalFunctionInMethod() {
        \\            function LocalFunctionInLocalFunctionInMethod() {}
        \\        }
        \\        interface LocalInterfaceInMethod {}
        \\        enum LocalEnumInMethod { LocalEnumMemberInMethod }
        \\    }
        \\
        \\    emptyMethod() { } // Non child functions method should not be duplicated
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestCompletionListPrivateMembers" {
    const content =
        \\class Foo {
        \\    private x;
        \\}
        \\
        \\class Bar extends Foo {
        \\    private y;
        \\    foo() {
        \\        this./**/
        \\    }
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
//                 "foo",
//                 "y",
//             },
//         },
//     });
}

test "TestCompletionListInTypeLiteralInTypeParameter12" {
    const content =
        \\interface Foo {
        \\    kind: 'foo';
        \\    one: string;
        \\}
        \\interface Bar {
        \\    kind: 'bar';
        \\    two: number;
        \\}
        \\
        \\declare function a<T extends Foo>(): void
        \\declare function a<T extends Bar>(): void
        \\a<{ kind: 'bar', /*0*/ }>();
        \\
        \\declare function b<T extends Foo>(kind: 'foo'): void
        \\declare function b<T extends Bar>(kind: 'bar'): void
        \\b<{/*1*/}>('bar');
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "0", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Unsorted = &.{
//                 "one",
//                 "two",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Unsorted = &.{
//                 "kind",
//                 "one",
//                 "two",
//             },
//         },
//     });
}

test "TestRenameNumericalIndexSingleQuoted" {
    const content =
        \\const foo = { [|0|]: true };
        \\foo[[|0|]];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRenameAtRangesWithText(undefined, &.{.QuotePreference = lsutil.QuotePreference("single")}, "0");
}

test "TestGetOccurrencesSuper3" {
    const content =
        \\let x = {
        \\    a() {
        \\        return [|s/**/uper|].b();
        \\    },
        \\    b() {
        \\        return [|super|].a();
        \\    },
        \\    c: function () {
        \\        return [|super|].a();
        \\    }
        \\    d: () => [|super|].b();
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestCodeFixMissingTypeAnnotationOnExportsTypePredicate1" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\// @filename: index.ts
        \\export function isString(value: unknown) {
        \\  return typeof value === "string";
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Add return type 'value is string'",
        .NewFileContent = "export function isString(value: unknown): value is string {\n  return typeof value === \"string\";\n}",
        .Index = 0,
    });
}

test "TestCompletionsImport_fromAmbientModule" {
    const content =
        \\// @module: esnext
        \\// @Filename: /a.ts
        \\declare module "m" {
        \\    export const x: number;
        \\}
        \\// @Filename: /b.ts
        \\/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyApplyCodeActionFromCompletion(undefined, undefined(""), &.{
//         .Name =        "x",
//         .Source =      "m",
//         .Description = "Add import from \"m\"",
//         .NewFileContent = undefined("import { x } from \"m\";\n\n"),
//     });
}

test "TestQuickinfoVerbosityNamespace" {
    const content =
        \\// @filename: /1.ts
        \\export {};
        \\class Foo<T> {
        \\    y: string;
        \\}
        \\namespace Foo/*1*/ {
        \\    export var y: number = 1;
        \\    export var x: string = "hello";
        \\    export var w = "world";
        \\    var z = 2;
        \\}
        \\// @filename: /2.ts
        \\export namespace Foo {
        \\    export var y: number = 1;
        \\    export var x: string = "hello";
        \\}
        \\// @filename: /3.ts
        \\import * as Foo_1 from "./b";
        \\export declare namespace ns/*2*/ {
        \\    import Foo = Foo_1.Foo;
        \\    export { Foo };
        \\    export const c: number;
        \\    export const d = 1;
        \\    let e: Apple;
        \\    export let f: Apple;
        \\}
        \\interface Apple {
        \\    a: string;
        \\}
        \\// @filename: /4.ts
        \\class Foo<T> {
        \\    y!: T;
        \\}
        \\namespace Two/*3*/ {
        \\    export const f = new Foo<number>();
        \\}
        \\// @filename: /5.ts
        \\namespace Two {
        \\    export const g = new Foo<string>();
        \\}
        \\// @filename: /6.ts
        \\namespace OnlyLocal/*4*/ {
        \\    const bar: number;
        \\}
        \\// @filename: foo.ts
        \\export function foo() { return "foo"; }
        \\import("/*5*/./foo")
        \\var x = import("./foo")
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"1" = .{0, 1}, .@"2" = .{0, 1, 2}, .@"3" = .{0, 1, 2}, .@"4" = .{0, 1}, .@"5" = .{0, 1}});
}

test "TestRenameDestructuringAssignmentInForOf" {
    const content =
        \\// @strict: false
        \\interface I {
        \\    [|[|{| "contextRangeIndex": 0 |}property1|]: number;|]
        \\    property2: string;
        \\}
        \\var elems: I[];
        \\
        \\var [|[|{| "contextRangeIndex": 2 |}property1|]: number|], p2: number;
        \\for ([|{ [|{| "contextRangeIndex": 4 |}property1|] } of elems|]) {
        \\    [|property1|]++;
        \\}
        \\for ([|{ [|{| "contextRangeIndex": 7 |}property1|]: p2 } of elems|]) {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyNoErrors(undefined);
    // f.VerifyBaselineRename(undefined, null , f.Ranges()[1], f.Ranges()[8], f.Ranges()[3], f.Ranges()[5], f.Ranges()[6]);
}

test "TestImportNameCodeFix_all2" {
    const content =
        \\// @Filename: /path.ts
        \\export declare function join(): void;
        \\// @Filename: /os.ts
        \\export declare function homedir(): void;
        \\// @Filename: /index.ts
        \\
        \\join();
        \\homedir();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/index.ts");
    _ = f.VerifyCodeFixAll(undefined, .{
        .FixID = "fixMissingImport",
        .NewFileContent = "import { homedir } from \"./os\";\nimport { join } from \"./path\";\n\njoin();\nhomedir();",
    });
}

